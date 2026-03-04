function [resultImg, numStains, stainPercentage, processingTime] = CottonStain(img)

    tStart = tic;

    % ===== 0) Ensure RGB =====
    if size(img,3) == 1
        rgbImg = cat(3, img, img, img);
    else
        rgbImg = img;
    end
    rgbD = im2double(rgbImg);

    % ===== 1) Robust glove segmentation (bright object) =====
    Igray = rgb2gray(rgbD);
    Is = imgaussfilt(Igray, 2);

    gloveMask = imbinarize(Is, 'adaptive', ...
        'Sensitivity', 0.90, ...
        'ForegroundPolarity', 'bright');

    gloveMask = imfill(gloveMask, 'holes');
    gloveMask = bwareaopen(gloveMask, 8000);
    gloveMask = imclose(gloveMask, strel('disk', 12));
    gloveMask = bwareafilt(gloveMask, 1);

    if ~any(gloveMask(:))
        resultImg = im2uint8(rgbImg);
        numStains = 0;
        stainPercentage = 0;
        processingTime = toc(tStart);
        return;
    end

    % ===== 2) Color-based stain detection (HSV + Lab chroma) =====
    hsvImg = rgb2hsv(rgbD);
    H = hsvImg(:,:,1);
    S = hsvImg(:,:,2);
    V = hsvImg(:,:,3);

    labImg = rgb2lab(rgbD);
    L = labImg(:,:,1);
    a = labImg(:,:,2);
    b = labImg(:,:,3);
    chroma = hypot(a, b);

    huePurpleBlue = (H > 0.60) & (H < 0.92);

    stainCandidate = gloveMask & ...
        (S > 0.15) & ...
        (chroma > 12) & ...
        (L < 97) & ...
        (V < 0.98) & ...
        huePurpleBlue;

    stainMask = bwareaopen(stainCandidate, 40);
    stainMask = imclose(stainMask, strel('disk', 3));
    stainMask = imfill(stainMask, 'holes');

    if ~any(stainMask(:))
        stainCandidate2 = gloveMask & (S > 0.12) & (chroma > 14) & (L < 97) & (V < 0.98);
        stainMask = bwareaopen(stainCandidate2, 40);
        stainMask = imclose(stainMask, strel('disk', 3));
        stainMask = imfill(stainMask, 'holes');
    end

    % ===== 3) Count + percentage =====
    glovePixels = nnz(gloveMask);
    stainPixels = nnz(stainMask);
    stainPercentage = 100 * (stainPixels / max(1, glovePixels));

    CC = bwconncomp(stainMask);
    numStains = CC.NumObjects;

    % ===== 4) Annotate: PLAIN RED BOX ONLY =====
    resultImg = im2uint8(rgbImg);

    if numStains > 0
        stats = regionprops(CC, 'BoundingBox', 'Area');
        hasInsertShape = (exist('insertShape', 'file') == 2);

        for k = 1:numel(stats)
            if stats(k).Area < 40
                continue;
            end
            bb = stats(k).BoundingBox;

            if hasInsertShape
                % Plain red rectangle only
                resultImg = insertShape(resultImg, 'Rectangle', bb, ...
                    'Color', 'red', 'LineWidth', 4);
            else
                % Fallback plain red rectangle only
                x = bb(1); y = bb(2); w = bb(3); h = bb(4);
                resultImg = insertRectFallback(resultImg, x, y, w, h, 4);
            end
        end
    end

    processingTime = toc(tStart);
end

function out = insertRectFallback(in, x, y, w, h, lineWidth)
% Draw a plain red rectangle directly into an RGB uint8 image.
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

    % Top and bottom edges
    rowStrip = repmat(reshape(red, 1, 1, 3), 1, numel(xs), 1);
    for yy = y1:min(y1+t-1, H)
        out(yy, xs, :) = rowStrip;
    end
    for yy = max(y2-t+1, 1):y2
        out(yy, xs, :) = rowStrip;
    end

    % Left and right edges
    colStrip = repmat(reshape(red, 1, 1, 3), numel(ys), 1, 1);
    for xx = x1:min(x1+t-1, W)
        out(ys, xx, :) = colStrip;
    end
    for xx = max(x2-t+1, 1):x2
        out(ys, xx, :) = colStrip;
    end
end