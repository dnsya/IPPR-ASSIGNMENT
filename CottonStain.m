function [resultImg, numStains, stainPercentage, processingTime] = CottonStain(img)

    tic;

    % Step 1: Ensure RGB
    if size(img,3) == 1
        rgbImg = cat(3, img, img, img);
    else
        rgbImg = img;
    end
    rgbD = im2double(rgbImg);

    % Step 2: Glove Segmentation
    Igray = rgb2gray(rgbD);
    Is = imgaussfilt(Igray, 2);

    gloveMask = imbinarize(Is, 'adaptive', ...
        'Sensitivity', 0.90, ...
        'ForegroundPolarity', 'bright');

    gloveMask = imfill(gloveMask, 'holes');
    gloveMask = bwareaopen(gloveMask, 8000);
    gloveMask = imclose(gloveMask, strel('disk', 10));
    gloveMask = bwareafilt(gloveMask, 1);

    % Remove wrist / arm area
    stats = regionprops(gloveMask, 'BoundingBox');
    bb = stats.BoundingBox;

    cutoffY = round(bb(2) + 0.75 * bb(4));
    gloveMask(cutoffY:end, :) = 0;

    % Safety
    if ~any(gloveMask(:))
        resultImg = im2uint8(rgbImg);
        numStains = 0;
        stainPercentage = 0;
        processingTime = toc(tStart);
        return;
    end

    % Step 3: Color Features
    hsvImg = rgb2hsv(rgbD);
    H = hsvImg(:,:,1);
    S = hsvImg(:,:,2);
    V = hsvImg(:,:,3);

    labImg = rgb2lab(rgbD);
    L = labImg(:,:,1);
    a = labImg(:,:,2);
    b = labImg(:,:,3);
    chroma = hypot(a, b);

    % Strong purple detection
    huePurple = (H > 0.70) & (H < 0.90);

    stainCandidate = gloveMask & ...
        (S > 0.25) & ...
        (chroma > 20) & ...
        (L < 85) & ...
        (V < 0.90) & ...
        huePurple;

    % Morphological cleanup
    stainMask = bwareaopen(stainCandidate, 80);
    stainMask = imclose(stainMask, strel('disk', 4));
    stainMask = imfill(stainMask, 'holes');

    % Remove false positives
    CC = bwconncomp(stainMask);
    stats = regionprops(CC, 'Area', 'Eccentricity');

    cleanMask = false(size(stainMask));

    for k = 1:CC.NumObjects
        area = stats(k).Area;
        ecc  = stats(k).Eccentricity;

        if area > 100 && ecc < 0.98
            cleanMask(CC.PixelIdxList{k}) = true;
        end
    end

    stainMask = cleanMask;

    % Step 4: Count Stains
    glovePixels = nnz(gloveMask);
    stainPixels = nnz(stainMask);
    stainPercentage = 100 * (stainPixels / max(1, glovePixels));

    CC = bwconncomp(stainMask);
    numStains = CC.NumObjects;

    % Step 5: Draw red bounding boxes
    resultImg = im2uint8(rgbImg);

    if numStains > 0
        stats = regionprops(CC, 'BoundingBox', 'Area');

        for k = 1:numel(stats)
            if stats(k).Area < 100
                continue;
            end

            bb = stats(k).BoundingBox;

            x = bb(1); 
            y = bb(2); 
            w = bb(3); 
            h = bb(4);

            resultImg = insertRectFallback(resultImg, x, y, w, h, 4);
        end
    end

    processingTime = toc;
end


% ===== Custom rectangle drawing =====
function out = insertRectFallback(in, x, y, w, h, lineWidth)

    if nargin < 6, lineWidth = 4; end

    out = in;
    [H, W, ~] = size(out);

    x1 = max(1, floor(x));
    y1 = max(1, floor(y));
    x2 = min(W, ceil(x + w));
    y2 = min(H, ceil(y + h));

    t = max(1, round(lineWidth));

    xs = x1:x2;
    ys = y1:y2;

    red = uint8([255 0 0]);

    % Top & Bottom
    for yy = y1:min(y1+t-1, H)
        out(yy, xs, 1) = 255;
        out(yy, xs, 2) = 0;
        out(yy, xs, 3) = 0;
    end
    for yy = max(y2-t+1,1):y2
        out(yy, xs, 1) = 255;
        out(yy, xs, 2) = 0;
        out(yy, xs, 3) = 0;
    end

    % Left & Right
    for xx = x1:min(x1+t-1, W)
        out(ys, xx, 1) = 255;
        out(ys, xx, 2) = 0;
        out(ys, xx, 3) = 0;
    end
    for xx = max(x2-t+1,1):x2
        out(ys, xx, 1) = 255;
        out(ys, xx, 2) = 0;
        out(ys, xx, 3) = 0;
    end
end