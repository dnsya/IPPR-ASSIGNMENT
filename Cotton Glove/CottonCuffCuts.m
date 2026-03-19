function [resultImg, numCuts, cutPercentage, processingTime] = CottonCuffCuts(img)

    % Start timer
    tic;

    % Step 1: Ensure RGB format and convert to grayscale
    if size(img,3) == 1
        rgbImg = cat(3, img, img, img);
    else
        rgbImg = img;
    end

    grayImg = im2double(rgb2gray(rgbImg));
    [rows, cols] = size(grayImg);

    % Step 2: Glove Segmentation
    t = graythresh(grayImg);
    gloveMask = grayImg > max(0.35, 0.9 * t);

    gloveMask = imfill(gloveMask, 'holes');
    gloveMask = bwareaopen(gloveMask, 3000);
    gloveMask = imclose(gloveMask, strel('disk', 10));
    gloveMask = bwareafilt(gloveMask, 1);

    if ~any(gloveMask(:))
        resultImg = rgbImg;
        numCuts = 0;
        cutPercentage = 0;
        processingTime = toc(tStart);
        return;
    end

    % Step 3: Tighter cuff region
    stats = regionprops(gloveMask, 'BoundingBox');
    bb = stats.BoundingBox;

    % Define cuff as the bottom 20% of the glove bounding box height
    cuffTop = round(bb(2) + 0.80 * bb(4));

    cuffMask = false(rows, cols);
    cuffMask(cuffTop:end, :) = true;

    cuffMask = cuffMask & gloveMask;

    % Step 4: Convex hull difference
    hullMask = bwconvhull(cuffMask);

    cutCand = hullMask & ~cuffMask;

    % Restrict candidates to within 6px dilation of the cuff boundary
    edgeZone = imdilate(cuffMask, strel('disk', 6));
    cutCand = cutCand & edgeZone;

    % Step 5: Strong cleanup
    cutCand = imclose(cutCand, strel('disk', 5));
    cutCand = bwareaopen(cutCand, 600);   % Remove small false positive regions below 600px area

    % Step 6: Shape filtering
    cc = bwconncomp(cutCand);
    stats = regionprops(cc, 'Area', 'BoundingBox', 'Extent');

    validMask = false(rows, cols);
    numCuts = 0;

    for k = 1:cc.NumObjects
        A = stats(k).Area;
        ext = stats(k).Extent;   % ratio of region pixels to bounding box area

        bb2 = stats(k).BoundingBox;
        width = bb2(3);
        height = bb2(4);

        % Accept region as a cut if it meets all shape criteria
        if A > 1000 && ...          % minimum area to exclude noise
           width > 20 && ...        % minimum width to exclude thin artifacts
           height > 15 && ...       % minimum height to exclude horizontal scratches
           ext < 0.8               % low extent indicates an irregular, cut-like shape

            validMask(cc.PixelIdxList{k}) = true;
            numCuts = numCuts + 1;
        end
    end

    % Step 7: Count Percentage
    cutPixels  = nnz(validMask);
    cuffPixels = nnz(cuffMask);
    cutPercentage = 100 * (cutPixels / max(cuffPixels,1));

    % Step 8: Draw bounding boxes
    resultImg = im2uint8(rgbImg);

    cc2 = bwconncomp(validMask);
    stats2 = regionprops(cc2, 'BoundingBox');

    for k = 1:numel(stats2)
        bb = stats2(k).BoundingBox;

        x = round(bb(1)); y = round(bb(2));
        w = round(bb(3)); h = round(bb(4));

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

    processingTime = toc; % Return elapsed time
end