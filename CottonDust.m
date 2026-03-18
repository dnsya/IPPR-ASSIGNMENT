function [resultImg, dustCount, dustPercentage, processingTime] = CottonDust(img)
    
    tic;

    % STEP 1: Convert to grayscale
    if size(img,3) == 3
        grayImg = rgb2gray(img);
    else
        grayImg = img;
    end
    grayImg = im2double(grayImg);

    % Ensure we have RGB for HSV + output
    if size(img,3) == 1
        rgbImg = cat(3, img, img, img);
    else
        rgbImg = img;
    end
    rgbD = im2double(rgbImg);

    % STEP 2: Robust glove segmentation
    Is = imgaussfilt(grayImg, 2);

    gloveMask = imbinarize(Is, 'adaptive', ...
        'Sensitivity', 0.90, ...
        'ForegroundPolarity', 'bright');

    gloveMask = imfill(gloveMask, 'holes');
    gloveMask = bwareaopen(gloveMask, 8000);
    gloveMask = imclose(gloveMask, strel('disk', 12));
    gloveMask = bwareafilt(gloveMask, 1);

    % Shrink glove mask to avoid edge artifacts
    gloveMask2 = imerode(gloveMask, strel('disk', 8));
    if nnz(gloveMask2) < 1000
        gloveMask2 = gloveMask; 
    end

    % STEP 3: Multi-scale dust enhancement
    Iblur = imgaussfilt(grayImg, 2);

    Idust = zeros(size(grayImg));
    for r = [3 7 11]
        Idust = Idust + imbothat(Iblur, strel('disk', r));
    end
    Idust = mat2gray(Idust);

    % Remove background response BEFORE thresholding
    Idust(~gloveMask2) = 0;

    % STEP 4: Threshold using only glove pixels
    vals = Idust(gloveMask2);
    vals = vals(vals > 0);

    if isempty(vals)
        BW = false(size(Idust));
    else
        thr = graythresh(vals) * 0.70;   
        BW = Idust > thr;
    end

    % Restrict detection to glove area
    BW = BW & gloveMask2;

    % HSV dust gating
    hsvImg = rgb2hsv(rgbD);
    S = hsvImg(:,:,2); % saturation
    V = hsvImg(:,:,3); % brightness

    Vg = V(gloveMask2);
    Sg = S(gloveMask2);

    % Robust thresholds using sorted values 
    Vthr = percentile_manual(Vg, 25);      % dust tends to be darker than this
    Sthr = percentile_manual(Sg, 60);      % dust often slightly more saturated than glove fibers

    hsvDust = gloveMask2 & (V < Vthr) & (S > Sthr);

    % Combine HSV gate with existing BW
    BW = BW & hsvDust;

    % STEP 5: Dark spot filtering (grayscale + shadow suppression)
    glovePixelsGray = grayImg(gloveMask2);
    mu = mean(glovePixelsGray);
    sig = std(glovePixelsGray);

    darkMask = grayImg < (mu - 0.6*sig);   

    % Local contrast check to suppress shadows (shadows are smooth)
    illum = imgaussfilt(grayImg, 15);
    localDiff = illum - grayImg;
    localDiff = mat2gray(localDiff);
    localMask = localDiff > 0.04;          

    BW = BW & darkMask & localMask;

    % STEP 6: Cleanup
    BW = imclearborder(BW);
    BW = bwareaopen(BW, 8);
    BW = imclose(BW, strel('disk', 2));

    BW = BW & ~bwareaopen(BW, 800);

    % STEP 7: Group nearby dust into regions for bounding boxes
    BWgrouped = imdilate(BW, strel('disk', 15));
    BWgrouped = imclose(BWgrouped, strel('disk', 5));
    BWgrouped = bwareaopen(BWgrouped, 50);

    % STEP 8: Calculate metrics
    dustCount = bwconncomp(BW).NumObjects;
    dustPixels = nnz(BW);
    glovePixels = nnz(gloveMask);
    dustPercentage = (dustPixels / max(glovePixels, 1)) * 100;

    % STEP 9: Draw red boxes to show defect location
    resultImg = im2uint8(rgbImg);

    cc = bwconncomp(BWgrouped);
    stats = regionprops(cc, 'BoundingBox');

    [rows, cols, ~] = size(resultImg);

    for k = 1:numel(stats)
        bbox = stats(k).BoundingBox;
        x = round(bbox(1));
        y = round(bbox(2));
        w = round(bbox(3));
        h = round(bbox(4));

        margin = 5;
        x = max(1, x - margin);
        y = max(1, y - margin);
        w = w + 2*margin;
        h = h + 2*margin;

        x2 = min(cols, x + w);
        y2 = min(rows, y + h);

        lw = 3;

        % Top
        resultImg(y:min(y+lw,y2), x:x2, 1) = 255;
        resultImg(y:min(y+lw,y2), x:x2, 2:3) = 0;
        % Bottom
        resultImg(max(y2-lw,1):y2, x:x2, 1) = 255;
        resultImg(max(y2-lw,1):y2, x:x2, 2:3) = 0;
        % Left
        resultImg(y:y2, x:min(x+lw,x2), 1) = 255;
        resultImg(y:y2, x:min(x+lw,x2), 2:3) = 0;
        % Right
        resultImg(y:y2, max(x2-lw,1):x2, 1) = 255;
        resultImg(y:y2, max(x2-lw,1):x2, 2:3) = 0;
    end
    
    processingTime = toc;
end

% Helper to calculate percentile
function p = percentile_manual(x, q)
    x = x(:);
    x = x(~isnan(x));
    if isempty(x), p = NaN; return; end
    x = sort(x);
    n = numel(x);

    pos = 1 + (q/100) * (n - 1);
    lo = floor(pos);
    hi = ceil(pos);

    if lo == hi
        p = x(lo);
    else
        w = pos - lo;
        p = (1 - w) * x(lo) + w * x(hi);
    end
end
