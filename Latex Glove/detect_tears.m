function [tearMask, tearStats, numTears] = detect_tears(I, gloveMask)
% DETECT_TEARS  Detects tear defects in latex gloves based on exposed skin colour.
%
% When the glove material tears, the wearer's skin becomes visible through
% the hole. This function detects those skin-coloured regions inside the
% glove boundary as tears.
%
% INPUT:
%   I         - RGB image of the glove (uint8 or double)
%   gloveMask - Binary mask of the glove region (from segment_glove_hsv)
%
% OUTPUT:
%   tearMask  - Binary mask of detected tear regions
%   tearStats - regionprops struct array for each detected tear
%   numTears  - Number of tears detected

    %% ---------------------------------------------------------------
    %  STEP 1: Preprocessing — convert to double and extract channels
    %% ---------------------------------------------------------------
    Iproc = im2double(I);

    R = Iproc(:,:,1);
    G = Iproc(:,:,2);
    B = Iproc(:,:,3);

    % Normalised RGB reduces the effect of illumination intensity,
    % making the skin-colour rule more robust across lighting conditions.
    sumRGB = R + G + B + eps;
    rNorm  = R ./ sumRGB;
    gNorm  = G ./ sumRGB;

    %% ---------------------------------------------------------------
    %  STEP 2: Skin-colour detection
    %  Rules target pale/light skin using normalised chromaticity
    %  (rNorm, gNorm) combined with absolute brightness thresholds.
    %% ---------------------------------------------------------------
    skinMask = (rNorm > 0.34 & rNorm < 0.60) & ...   % Red chromaticity range
               (gNorm > 0.25 & gNorm < 0.45) & ...   % Green chromaticity range
               (R > 0.60 & G > 0.50 & B > 0.45);     % Overall brightness (pale skin)

    % Restrict detection to inside the glove boundary only
    skinMask = skinMask & gloveMask;

    %% ---------------------------------------------------------------
    %  STEP 3: Morphological cleanup
    %  imopen removes isolated noise pixels; imclose reconnects nearby
    %  skin fragments that belong to the same tear; bwareaopen discards
    %  any remaining tiny blobs.
    %% ---------------------------------------------------------------
    skinMask = imopen(skinMask,   strel('disk', 3));
    skinMask = imclose(skinMask,  strel('disk', 5));
    skinMask = bwareaopen(skinMask, 50);

    %% ---------------------------------------------------------------
    %  STEP 4: Connected-component analysis and region filtering
    %  Each connected skin region is evaluated by area and mean
    %  brightness. Very small or dark regions are rejected as noise.
    %% ---------------------------------------------------------------
    CC    = bwconncomp(skinMask);
    Igray = rgb2gray(Iproc);

    stats = regionprops(CC, Igray, ...
                        'Area', 'Centroid', 'BoundingBox', ...
                        'Eccentricity', 'MeanIntensity');

    validTears = false(1, length(stats));

    for i = 1:length(stats)
        areaOK       = stats(i).Area > 55 && stats(i).Area < 5000;
        brightnessOK = stats(i).MeanIntensity > 0.35;   % True skin is bright
        validTears(i) = areaOK && brightnessOK;
    end

    %% ---------------------------------------------------------------
    %  STEP 5: Build final outputs
    %% ---------------------------------------------------------------
    tearMask  = ismember(labelmatrix(CC), find(validTears));
    tearStats = stats(validTears);
    numTears  = nnz(validTears);

    fprintf('Tear Detection: Found %d tear(s)\n', numTears);

    %% ---------------------------------------------------------------
    %  STEP 6: Debug visualisation — 6-panel figure
    %% ---------------------------------------------------------------

    % Build a skin-probability map for display
    skinChroma = rNorm .* double(gloveMask);   % rNorm inside glove only

    % Highlight accepted tear regions in green, rejected in red
    labelImg = labelmatrix(CC);
    acceptedMask = ismember(labelImg, find(validTears));
    rejectedMask = ismember(labelImg, find(~validTears & cellfun(@numel, CC.PixelIdxList) > 0));

    overlayRGB        = im2double(I);
    overlayRGB(:,:,1) = overlayRGB(:,:,1) + 0.45 .* double(acceptedMask);
    overlayRGB(:,:,2) = overlayRGB(:,:,2) + 0.45 .* double(rejectedMask);
    overlayRGB        = min(overlayRGB, 1);

    figure('Name', 'Tear Detection Debug', 'NumberTitle', 'off');

    subplot(2, 3, 1)
    imshow(Igray, [])
    title('Preprocessed Grayscale')

    subplot(2, 3, 2)
    imshow(skinChroma, [])
    title('Skin Chromaticity (rNorm inside glove)')

    subplot(2, 3, 3)
    imshow(skinMask)
    title('Skin Mask (after morphology)')

    subplot(2, 3, 4)
    imshow(overlayRGB)
    title('Accepted (green) vs Rejected (red) Regions')

    subplot(2, 3, 5)
    imshow(I)
    hold on
    for i = 1:numTears
        rectangle('Position', tearStats(i).BoundingBox, ...
                  'EdgeColor', 'r', 'LineWidth', 2)
        plot(tearStats(i).Centroid(1), tearStats(i).Centroid(2), ...
             'r+', 'MarkerSize', 14, 'LineWidth', 2)
        text(tearStats(i).Centroid(1) + 10, tearStats(i).Centroid(2), ...
             sprintf('T%d', i), 'Color', 'r', 'FontWeight', 'bold')
    end
    title(['Detected Tears: ' num2str(numTears)])
    hold off

    subplot(2, 3, 6)
    imshow(tearMask)
    title('Final Tear Mask')

end