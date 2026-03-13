function gloveMask = segment_glove_hsv(I)
% SEGMENT_GLOVE_HSV  Robust glove segmentation using adaptive HSV thresholds.
%
% INPUT:
%   I         - RGB image (uint8 or double)
%
% OUTPUT:
%   gloveMask - Binary mask of the segmented glove region
%
% METHOD OVERVIEW:
%   1. Convert image to HSV colour space
%   2. Apply loose blue-range threshold to create rough glove mask
%   3. Retain the largest connected blue object (assumed to be the glove)
%   4. Adaptively refine thresholds using the glove region statistics
%   5. Morphological cleanup to produce a clean final mask

    %% ---------------------------------------------------------------
    %  STEP 1: Convert to HSV colour space
    %  HSV separates hue (colour) from brightness, making colour-based
    %  segmentation more robust to lighting changes.
    %% ---------------------------------------------------------------
    I   = im2double(I);
    HSV = rgb2hsv(I);
    H   = HSV(:,:,1);   % Hue
    S   = HSV(:,:,2);   % Saturation
    V   = HSV(:,:,3);   % Value (brightness)

    %% ---------------------------------------------------------------
    %  STEP 2: Initial loose blue-range selection
    %  A slightly wider hue range is used intentionally so that darker
    %  shadow areas and lower-saturation edges of the glove are included.
    %% ---------------------------------------------------------------
    hMask    = (H > 0.48) & (H < 0.78);    % Blue hue range
    sMask    = S > 0.15;                    % Allow low saturation (shadows)
    vMask    = V > 0.15;                    % Allow darker glove regions
    roughMask = hMask & sMask & vMask;

    % Fill internal holes and remove tiny noise blobs
    roughMask = imfill(roughMask, 'holes');
    roughMask = bwareaopen(roughMask, 3000);

    %% ---------------------------------------------------------------
    %  STEP 3: Keep only the largest blue connected object (the glove)
    %% ---------------------------------------------------------------
    CC = bwconncomp(roughMask);

    if CC.NumObjects == 0
        gloveMask = false(size(roughMask));
        return;
    end

    numPixels             = cellfun(@numel, CC.PixelIdxList);
    [~, idx]              = max(numPixels);
    gloveMask             = false(size(roughMask));
    gloveMask(CC.PixelIdxList{idx}) = true;

    %% ---------------------------------------------------------------
    %  STEP 4: Adaptive threshold refinement
    %  Compute S and V statistics from the rough glove mask and tighten
    %  the thresholds to remove low-saturation / dark non-glove pixels.
    %% ---------------------------------------------------------------
    gloveS  = S(gloveMask);
    gloveV  = V(gloveMask);

    sThresh   = max(0.10, mean(gloveS) - 0.8 * std(gloveS));
    vThresh   = max(0.10, mean(gloveV) - 1.0 * std(gloveV));

    gloveMask = gloveMask & (S > sThresh) & (V > vThresh);

    %% ---------------------------------------------------------------
    %  STEP 4: Morphological cleanup
    %  imclose bridges small gaps, imfill removes interior holes, and
    %  imopen removes minor protrusions along the glove boundary.
    %% ---------------------------------------------------------------
    gloveMask = imclose(gloveMask, strel('disk', 7));   % Bridge small gaps
    gloveMask = imfill(gloveMask, 'holes');              % Fill interior holes
    gloveMask = imopen(gloveMask,  strel('disk', 3));   % Gentle edge cleanup

    %% ---------------------------------------------------------------
    %  STEP 5: Final safety cleanup — remove any remaining small blobs
    %% ---------------------------------------------------------------
    gloveMask = bwareaopen(gloveMask, 5000);

end