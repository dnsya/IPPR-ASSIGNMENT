function [resultImg, numLooseYarns, yarnPercentage, processingTime] = CottonLooseYarn(img)
    % issue: unable to detect LooseYarn2,3,4
    % CottonLooseYarn - Detects loose threads/yarns on cotton gloves (protruding filaments)
    % Outputs:
    %   resultImg        - Image with loose yarns marked
    %   numLooseYarns    - Number of loose yarn defects detected
    %   yarnPercentage   - Percentage area (yarn pixels / glove pixels) * 100
    %   processingTime   - Time taken for processing

    tic;

    % --- STEP 1: Grayscale ---
    if size(img,3) == 3
        grayImg = rgb2gray(img);
    else
        grayImg = img;
    end
    grayImg = im2double(grayImg);

    % --- STEP 2: Segment the glove (bright object on darker background) ---
    % Robust threshold using Otsu, then bias a bit lower to include the whole glove
    t = graythresh(grayImg);
    gloveMask = grayImg > max(0.35, t * 0.90);

    gloveMask = imfill(gloveMask, 'holes');
    gloveMask = bwareaopen(gloveMask, 2000);           % remove small bright noise
    gloveMask = imclose(gloveMask, strel('disk', 8));  % smooth boundary

    % Keep only the largest connected component (the glove)
    gloveMask = bwareafilt(gloveMask, 1);
    S = regionprops(gloveMask, 'BoundingBox');
    bb = S.BoundingBox;              % [x y width height]
    gloveSize = max(bb(3), bb(4));   % biggest dimension in pixels
    
    rOuter = round(0.10 * gloveSize);  % 8% of glove size (good default)
    rOuter = max(25, min(rOuter, 55)); % clamp between 15 and 45

    % --- STEP 3: Define a boundary search band (where yarn appears) ---
    % Yarn protrudes outside/near the edge, so look in a ring around the glove boundary
    bandOuter = imdilate(gloveMask, strel('disk', rOuter)) & ~gloveMask;   % outside ring
    searchBand = bandOuter;

    % --- STEP 4: Enhance thin bright filaments (white top-hat, multi-angle lines) ---
    % Top-hat emphasizes small bright objects compared to local background
    Ieq = imadjust(grayImg);

    % Multi-orientation line top-hat helps for curly/angled yarn
    angles = 0:15:165;                 % finer angles help curved strands
    lineLens = [17 25 35];             % multi-scale lengths
    tophatSum = zeros(size(Ieq));
    for L = lineLens
        for a = angles
            seLine = strel('line', L, a);
            tophatSum = max(tophatSum, imtophat(Ieq, seLine));  % use max not sum
        end
    end
    tophatSum = mat2gray(tophatSum);

    % Restrict to the boundary band only
    filamentResponse = tophatSum;
    filamentResponse(~searchBand) = 0;

    % --- STEP 5: Threshold the filament response ---
    % Lower threshold helps catch faint yarn strands
    vals = filamentResponse(filamentResponse > 0);
    if isempty(vals)
        yarnMask = false(size(filamentResponse));
    else
        thr = prctile(vals, 92);     % keep top 8% strongest responses
        yarnMask = filamentResponse > thr;
    end

    % --- STEP 6: Clean up and thin to get filament-like structures ---
    yarnMask = bwareaopen(yarnMask, 6);
    yarnMask = imclose(yarnMask, strel('line', 5, 0));
    yarnMask = imclose(yarnMask, strel('line', 5, 90));
    yarnMask = imclose(yarnMask, strel('disk', 1));

    % --- STEP 7: Component filtering (keep long, thin pieces) ---
    cc = bwconncomp(yarnMask);
    stats = regionprops(cc, 'Area', 'BoundingBox', 'Eccentricity', 'MajorAxisLength', 'Solidity');

    valid = false(numel(stats), 1);

    % Tuned for your images (small, thin strands)
    minLen  = 18;     % pixels
    minArea = 6;      % pixels
    maxArea = 1200;    % prevent big regions

    for k = 1:numel(stats)
        pix = cc.PixelIdxList{k};
        if any(gloveMask(pix))
            continue; % reject yarns that touch inside glove
        end
        
        % Loose yarn should be string-like (low solidity)
        if stats(k).Solidity > 0.55
            continue;
        end

        if stats(k).Area >= minArea && stats(k).Area <= maxArea && ...
           stats(k).MajorAxisLength >= minLen && ...
           stats(k).Eccentricity >= 0.60
            valid(k) = true;
        end
    end

    numLooseYarns = sum(valid);

    % Build final mask of valid components only
    finalMask = false(size(yarnMask));
    for k = 1:cc.NumObjects
        if valid(k)
            finalMask(cc.PixelIdxList{k}) = true;
        end
    end

    % --- STEP 8: Yarn percentage (within glove context) ---
    yarnPixels  = nnz(finalMask);
    glovePixels = nnz(gloveMask);
    yarnPercentage = (yarnPixels / max(glovePixels,1)) * 100;

    % --- STEP 9: Result image and marking ---
    resultImg = img;
    if size(resultImg,3) == 1
        resultImg = cat(3, resultImg, resultImg, resultImg);
    end

    % Draw bounding boxes around detected yarns
    cc2 = bwconncomp(finalMask);
    stats2 = regionprops(cc2, 'BoundingBox');
    
    resultImg = img;
    if size(resultImg,3)==1
        resultImg = cat(3,resultImg,resultImg,resultImg);
    end
    resultImg = im2uint8(resultImg);
    
    for k = 1:numel(stats2)
        bbox = stats2(k).BoundingBox;
        x = round(bbox(1)); y = round(bbox(2));
        w = round(bbox(3)); h = round(bbox(4));
    
        x = max(1,x); y = max(1,y);
        x2 = min(size(resultImg,2), x+w);
        y2 = min(size(resultImg,1), y+h);
    
        % draw rectangle in red
        lw = 2;
        resultImg(y:min(y+lw,y2), x:x2, 1) = 255; resultImg(y:min(y+lw,y2), x:x2, 2:3) = 0;
        resultImg(max(y2-lw,1):y2, x:x2, 1) = 255; resultImg(max(y2-lw,1):y2, x:x2, 2:3) = 0;
        resultImg(y:y2, x:min(x+lw,x2), 1) = 255; resultImg(y:y2, x:min(x+lw,x2), 2:3) = 0;
        resultImg(y:y2, max(x2-lw,1):x2, 1) = 255; resultImg(y:y2, max(x2-lw,1):x2, 2:3) = 0;
    end

    processingTime = toc;
end
