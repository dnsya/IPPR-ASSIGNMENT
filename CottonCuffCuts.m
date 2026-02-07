function [resultImg, numCuts, cutPercentage, processingTime] = CottonCuffCuts(img)

    tic;

    % STEP 1: Ensure RGB and grayscale
    if size(img,3) == 1
        rgbImg = cat(3, img, img, img);
    else
        rgbImg = img;
    end
    grayImg = rgb2gray(rgbImg);
    grayImg = im2double(grayImg);

    [rows, cols] = size(grayImg);

    % STEP 2: Glove segmentation
    % Otsu and slight bias to include glove completely
    t = graythresh(grayImg);
    gloveMask = grayImg > max(0.35, 0.90 * t);

    gloveMask = imfill(gloveMask, 'holes');
    gloveMask = bwareaopen(gloveMask, 2000);
    gloveMask = imclose(gloveMask, strel('disk', 10));
    gloveMask = bwareafilt(gloveMask, 1);  

    if ~any(gloveMask(:))
        resultImg = rgbImg;
        numCuts = 0;
        cutPercentage = 0;
        processingTime = toc(tStart);
        return;
    end

    % STEP 3: Cuff ROI (bottom area)
    cuffStartRow = round(rows * 0.55); 
    cuffROI = false(rows, cols);
    cuffROI(cuffStartRow:end, :) = true;

    cuffMask = gloveMask & cuffROI;
    
    % Find the lowest row of the cuff (bottom-most glove pixels in ROI)
    cuffRows = find(any(cuffMask, 2));
    cuffBottomRow = max(cuffRows);   % bottom edge of glove within cuff ROI

    % STEP 4: Convex hull trick (fills cut area)
    hullMask = bwconvhull(cuffMask, 'objects');

    % Candidate cut area = hull - actual cuff
    cutCand = hullMask & ~cuffMask;

    % Keep only candidates close to cuff boundary (avoid random hull fill far away)
    nearCuff = imdilate(cuffMask, strel('disk', 12));
    cutCand = cutCand & nearCuff;

    % Clean up
    cutCand = imclose(cutCand, strel('disk', 6));
    cutCand = bwareaopen(cutCand, 400);   % remove tiny noise

    % STEP 5: Component filtering
    cc = bwconncomp(cutCand);
    stats = regionprops(cc, 'Area', 'BoundingBox');

    valid = false(cc.NumObjects, 1);

    minArea = 800;       
    maxArea = 80000;      
    
    bottomTol = 12;

    for k = 1:cc.NumObjects
        pix = cc.PixelIdxList{k};
        [r, ~] = ind2sub(size(cutCand), pix);
        A = stats(k).Area;

        % Cuts are usually a big missing chunk; solidity tends to be moderate
        if A >= minArea && A <= maxArea && max(r) >= (cuffBottomRow - bottomTol)
            valid(k) = true;
        end
    end
    
    validIdx = find(valid);
    if ~isempty(validIdx)
        [~, m] = max([stats(validIdx).Area]);
        keep = validIdx(m);
    
        valid(:) = false;
        valid(keep) = true;
    end
    
    % Build final cut mask
    finalMask = false(rows, cols);
    for k = 1:cc.NumObjects
        if valid(k)
            finalMask(cc.PixelIdxList{k}) = true;
        end
    end

    numCuts = nnz(valid);

    % STEP 6: Percentage of cuff area
    cutPixels  = nnz(finalMask);
    cuffPixels = nnz(cuffMask);
    cutPercentage = (cutPixels / max(cuffPixels,1)) * 100;

    % STEP 7: Display results in red boxes
    resultImg = im2uint8(rgbImg);

    cc2 = bwconncomp(finalMask);
    stats2 = regionprops(cc2, 'BoundingBox');

    for k = 1:numel(stats2)
        bbox = stats2(k).BoundingBox;
        x = round(bbox(1)); y = round(bbox(2));
        w = round(bbox(3)); h = round(bbox(4));

        x = max(1, x); y = max(1, y);
        x2 = min(cols, x + w);
        y2 = min(rows, y + h);

        lw = 3;
        % top
        resultImg(y:min(y+lw,y2), x:x2, 1) = 255;
        resultImg(y:min(y+lw,y2), x:x2, 2:3) = 0;
        % bottom
        resultImg(max(y2-lw,1):y2, x:x2, 1) = 255;
        resultImg(max(y2-lw,1):y2, x:x2, 2:3) = 0;
        % left
        resultImg(y:y2, x:min(x+lw,x2), 1) = 255;
        resultImg(y:y2, x:min(x+lw,x2), 2:3) = 0;
        % right
        resultImg(y:y2, max(x2-lw,1):x2, 1) = 255;
        resultImg(y:y2, max(x2-lw,1):x2, 2:3) = 0;
    end

    processingTime = toc;
end
