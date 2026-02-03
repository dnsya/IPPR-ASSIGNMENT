function gloveMask = segment_glove_hsv(I)
% SEGMENT_GLOVE_HSV Robust glove segmentation using adaptive HSV thresholds

    %% Convert to HSV
    I = im2double(I);
    HSV = rgb2hsv(I);
    H = HSV(:,:,1);
    S = HSV(:,:,2);
    V = HSV(:,:,3);

    %% --- STEP 1: Initial loose blue selection (INCLUSIVE)
    hMask = (H > 0.48) & (H < 0.78);   % slightly wider blue range
    sMask = S > 0.15;                % allow low saturation (shadows)
    vMask = V > 0.15;                % allow darker glove regions

    roughMask = hMask & sMask & vMask;

    %% --- STEP 2: Keep largest blue object (likely glove)
    roughMask = imfill(roughMask, 'holes');
    roughMask = bwareaopen(roughMask, 3000);

    CC = bwconncomp(roughMask);
    if CC.NumObjects == 0
        gloveMask = false(size(roughMask));
        return;
    end

    numPixels = cellfun(@numel, CC.PixelIdxList);
    [~, idx] = max(numPixels);
    gloveMask = false(size(roughMask));
    gloveMask(CC.PixelIdxList{idx}) = true;

    %% --- STEP 3: Adaptive refinement based on glove stats
    gloveS = S(gloveMask);
    gloveV = V(gloveMask);

    sThresh = max(0.10, mean(gloveS) - 0.8*std(gloveS));
    vThresh = max(0.10, mean(gloveV) - 1.0*std(gloveV));

    gloveMask = gloveMask & (S > sThresh) & (V > vThresh);

    %% --- STEP 4: Morphology (SOFTER)
    gloveMask = imclose(gloveMask, strel('disk', 7));   % fill gaps
    gloveMask = imfill(gloveMask, 'holes');

    gloveMask = imopen(gloveMask, strel('disk', 3));    % gentle cleanup

    %% --- STEP 5: Final safety cleanup
    gloveMask = bwareaopen(gloveMask, 5000);

    fprintf('Glove segmentation completed (adaptive HSV)\n');
end
