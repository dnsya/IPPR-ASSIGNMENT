function [resultImg, dustCount, dustPercentage, processingTime] = CottonDust(img)
    % issue: dust detected, but shadow is classified as dust
    tic;

    % Convert to grayscale
    Igray = im2gray(img);
    Igray = im2double(Igray);

    % ===== 1) Robust glove segmentation =====
    Is = imgaussfilt(Igray, 2);

    gloveMask = imbinarize(Is, 'adaptive', ...
        'Sensitivity', 0.90, ...
        'ForegroundPolarity', 'bright');

    gloveMask = imfill(gloveMask, 'holes');
    gloveMask = bwareaopen(gloveMask, 8000);
    gloveMask = imclose(gloveMask, strel('disk', 12));
    gloveMask = bwareafilt(gloveMask, 1);

    % ===== 2) Dust enhancement (dark dust -> bright response) =====
    Iblur = imgaussfilt(Igray, 2);

    Idust = zeros(size(Igray));
    for r = [3 7 11]
        Idust = Idust + imbothat(Iblur, strel('disk', r));
    end
    Idust = mat2gray(Idust);

    % IMPORTANT: remove background response BEFORE thresholding
    Idust(~gloveMask) = 0;

    % ===== 3) Threshold using only glove pixels =====
    vals = Idust(gloveMask);
    vals = vals(vals > 0);

    if isempty(vals)
        BW = false(size(Idust));
    else
        thr = graythresh(vals) * 0.8;  % tune 0.7–0.9 if needed
        BW = Idust > thr;
    end

    % Restrict detection to glove area
    BW = BW & gloveMask;
    
    % Slightly shrink glove mask to avoid edge shading
    gloveMask2 = imerode(gloveMask, strel('disk', 5));
    BW = BW & gloveMask2;

    % -------- Dark dust filtering --------
    glovePixels = Igray(gloveMask);
    
    mu = mean(glovePixels);
    sig = std(glovePixels);
    
    darkMask = Igray < (mu - 1.0*sig);
    
    % --- shadow suppression via local contrast ---
    illum = imgaussfilt(Igray, 12);
    localDiff = illum - Igray;
    localDiff = mat2gray(localDiff);
    localMask = localDiff > 0.06;

    % Combine
    BW = BW & darkMask & localMask;

    % ===== 4) Cleanup =====
    % Remove border junks
    BW = imclearborder(BW);
    BW = bwareaopen(BW, 7);
    BW = imclose(BW, strel('disk', 2));
    
    % Remove big blobs (shadows)
    BW = BW & ~bwareaopen(BW, 600);

    % ===== 5) Metrics =====
    dustCount = bwconncomp(BW).NumObjects;

    dustPixels  = nnz(BW);
    glovePixels = nnz(gloveMask);
    dustPercentage = (dustPixels / max(glovePixels, 1)) * 100;

    % Overlay result
    resultImg = imoverlay(Igray, BW, [1 0 0]);

    processingTime = toc;
end
