function [stainMask, stainStats, numStains] = detect_stains(I, gloveMask)
% DETECT_STAINS  Robust stain detection for glove inspection using adaptive
%                local statistics, wrinkle suppression, and HSV colour gating.
%
% INPUT:
%   I         - RGB image (uint8 or double)
%   gloveMask - Binary mask of the glove region (from segment_glove_hsv)
%
% OUTPUT:
%   stainMask  - Binary mask of detected stain regions
%   stainStats - regionprops struct array for each detected stain
%   numStains  - Number of stains detected

    %% ---------------------------------------------------------------
    %  STEP 1: Preprocessing
    %  Convert to double and grayscale for intensity analysis.
    %  medfilt2 removes salt-and-pepper sensor noise without blurring edges.
    %  imgaussfilt (sigma=1.6) applies a light Gaussian smooth to suppress
    %% ---------------------------------------------------------------
    I      = im2double(I);
    Igray  = rgb2gray(I);

    % Noise removal
    Igray = medfilt2(Igray, [3 3]);
    Igray = imgaussfilt(Igray, 1.6);

    % Inner mask excludes glove edges from all analysis
    innerMask = imerode(gloveMask, strel('disk', 12));

    %% ---------------------------------------------------------------
    %  STEP 2: Illumination Normalisation
    %% ---------------------------------------------------------------
    localMean = imgaussfilt(Igray, 25);
    localStd  = imgaussfilt(abs(Igray - localMean), 25);

    % High-pass texture response: how much does each pixel deviate locally?
    highpass = abs(Igray - localMean) ./ (localStd + eps);

    % Model normal glove texture using inner mask statistics
    mu    = mean(highpass(innerMask), 'omitnan');
    sigma = std(highpass(innerMask),  'omitnan');

    % z-score deviation map: how many std deviations from normal glove texture?
    deviationMap = abs(highpass - mu) ./ (sigma + eps);

    %% ---------------------------------------------------------------
    %  STEP 3: Initial Stain Detection
    %% ---------------------------------------------------------------
    stainMask = deviationMap > 2.0;
    stainMask = stainMask & innerMask;

    %% ---------------------------------------------------------------
    %  STEP 4: Dark Stain Enhancement
    %% ---------------------------------------------------------------
    glovePixels = Igray(innerMask);
    muGlove     = mean(glovePixels);
    sigmaGlove  = std(glovePixels);

    % Adaptive dark threshold: 1.2 std deviations below this glove's mean
    darkThreshold = muGlove - 1.2 * sigmaGlove;
    darkPixels    = (Igray < darkThreshold) & innerMask;

    % Absolute dark threshold for very dark chemical / dirt stains
    veryDark = (Igray < 0.30) & innerMask;

    % Combine all three sources of evidence
    stainMask = stainMask | darkPixels | veryDark;

    %% ---------------------------------------------------------------
    %  STEP 5: Wrinkle Suppression
    %% ---------------------------------------------------------------
    [Gmag, ~] = imgradient(Igray);

    % Top 8% of gradient magnitudes inside the glove are candidate wrinkles
    wrinkleMask = Gmag > prctile(Gmag(innerMask), 92);
    wrinkleMask = bwareaopen(wrinkleMask, 40);   % Remove tiny noise blobs

    % Analyse shape of each high-gradient region
    CCw    = bwconncomp(wrinkleMask);
    statsW = regionprops(CCw, 'Area', 'Eccentricity', 'BoundingBox');

    validWrinkle = false(1, numel(statsW));

    for i = 1:numel(statsW)
        longThin   = statsW(i).Eccentricity > 0.95;   % Very elongated = wrinkle
        mediumArea = statsW(i).Area > 40 && statsW(i).Area < 3000;

        if longThin && mediumArea
            validWrinkle(i) = true;
        end
    end

    % Rebuild wrinkle mask from accepted regions only
    wrinkleMask = ismember(labelmatrix(CCw), find(validWrinkle));

    % Dilate to cover dark shadow pixels caused by the wrinkle edges
    wrinkleMask = imdilate(wrinkleMask, strel('disk', 3));

    % Subtract wrinkle regions from the stain candidate mask
    stainMask = stainMask & ~wrinkleMask;

    %% ---------------------------------------------------------------
    %  STEP 6: Morphological Cleanup
    %% ---------------------------------------------------------------
    stainMask = imopen(stainMask,  strel('disk', 8));   % Remove speckle
    stainMask = imclose(stainMask, strel('disk', 3));   % Reconnect fragments
    stainMask = bwareaopen(stainMask, 1000);             % Discard micro blobs
    stainMask = imfill(stainMask, 'holes');              % Fill interior holes

    %% ---------------------------------------------------------------
    %  STEP 7: Specular Reflection Removal
    %  Latex is glossy — bright specular highlights can survive the wrinkle
    %  Regions meeting both criteria are removed from the stain mask.
    %% ---------------------------------------------------------------
    reflectionMask = Igray > prctile(Igray(innerMask), 99);

    % Convert to HSV to check saturation
    hsv = rgb2hsv(I);
    S   = hsv(:,:,2);

    % Reflections are bright AND desaturated
    reflectionMask = reflectionMask & (S < 0.2);

    % Remove reflections from stain candidates
    stainMask = stainMask & ~reflectionMask;

    %% ---------------------------------------------------------------
    %  STEP 8: Region Filtering — Final Acceptance Gate
    %% ---------------------------------------------------------------
    CC    = bwconncomp(stainMask);
    stats = regionprops(CC, Igray, ...
                        'Area', 'BoundingBox', 'Centroid', ...
                        'Eccentricity', 'Solidity', 'MeanIntensity');

    % Compute mean HSV of the normal glove surface for colour comparison
    Ihsv  = rgb2hsv(I);
    H     = Ihsv(:,:,1);
    S     = Ihsv(:,:,2);
    V     = Ihsv(:,:,3);

    meanH = mean(H(innerMask), 'omitnan');
    meanS = mean(S(innerMask), 'omitnan');
    meanV = mean(V(innerMask), 'omitnan');

    valid = false(1, numel(stats));

    for i = 1:numel(stats)
        areaOK  = stats(i).Area >= 200 && stats(i).Area <= 20000;
        shapeOK = stats(i).Eccentricity < 0.97 && stats(i).Solidity > 0.45;

        % Per-region mean HSV
        regionMask = ismember(labelmatrix(CC), i);
        hMean      = mean(H(regionMask));
        sMean      = mean(S(regionMask));
        vMean      = mean(V(regionMask));

        % L1 colour distance from normal glove appearance
        colorDist = abs(hMean - meanH) + ...
                    abs(sMean - meanS) + ...
                    abs(vMean - meanV);

        if areaOK && shapeOK && colorDist > 0.20
            valid(i) = true;
        end
    end

    %% ---------------------------------------------------------------
    %  STEP 9: Final Output
    %% ---------------------------------------------------------------
    stainMask  = ismember(labelmatrix(CC), find(valid));
    stainStats = stats(valid);
    numStains  = sum(valid);

    fprintf('Stain Detection: Found %d stain(s)\n', numStains);

    %% ---------------------------------------------------------------
    %  STEP 10: Debug Visualisation — 6-panel figure
    %% ---------------------------------------------------------------
    figure('Name', 'Stain Detection Debug', 'NumberTitle', 'off', ...
           'Color', [0.15 0.15 0.15], 'Position', [100 100 1200 700]);

    % ── Panel 1: Preprocessed Grayscale ──────────────────────────────────────
    subplot(2, 3, 1)
    imshow(Igray, [])
    title('1. Preprocessed Grayscale', ...
          'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold')
    set(gca, 'Color', [0.15 0.15 0.15])

    % ── Panel 2: Deviation Map ────────────────────────────────────────────────
    subplot(2, 3, 2)
    imshow(deviationMap, [])
    title('2. Deviation Map (z-score)', ...
          'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold')
    set(gca, 'Color', [0.15 0.15 0.15])

    % ── Panel 3: Final Stain Mask ─────────────────────────────────────────────
    subplot(2, 3, 3)
    imshow(stainMask)
    title('3. Final Stain Mask', ...
          'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold')
    set(gca, 'Color', [0.15 0.15 0.15])

    % ── Panel 4: Wrinkle Mask ─────────────────────────────────────────────────
    subplot(2, 3, 4)
    imshow(wrinkleMask)
    title('4. Wrinkle Mask (suppressed)', ...
          'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold')
    set(gca, 'Color', [0.15 0.15 0.15])

    % ── Panel 5: Annotated Original ───────────────────────────────────────────
    subplot(2, 3, 5)
    imshow(I)
    hold on
    for i = 1:numStains
        bb = stainStats(i).BoundingBox;
        cx = stainStats(i).Centroid(1);
        cy = stainStats(i).Centroid(2);

        % Bounding box
        rectangle('Position', bb, ...
                  'EdgeColor', [1 0.85 0], 'LineWidth', 2)

        % Centroid marker
        plot(cx, cy, '+', 'Color', [1 0.85 0], ...
             'MarkerSize', 12, 'LineWidth', 2)

        % Label with stain index and area
        text(bb(1), bb(2) - 6, sprintf('S%d  (%.0f px)', i, stainStats(i).Area), ...
             'Color', [1 0.85 0], 'FontSize', 9, 'FontWeight', 'bold', ...
             'BackgroundColor', [0 0 0 0.5])
    end

    if numStains == 0
        titleStr = 'Detected Stains: None';
        titleCol = [0.6 1.0 0.6];   % green — clean glove
    else
        titleStr = sprintf('Detected Stains: %d', numStains);
        titleCol = [1.0 0.85 0.0];  % yellow — stains found
    end

    title(titleStr, 'Color', titleCol, 'FontSize', 11, 'FontWeight', 'bold')
    hold off
    set(gca, 'Color', [0.15 0.15 0.15])

    % ── Panel 6: Dark Pixels ──────────────────────────────────────────────────
    subplot(2, 3, 6)
    imshow(darkPixels)
    title('6. Dark Pixel Map', ...
          'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold')
    set(gca, 'Color', [0.15 0.15 0.15])

    % ── Figure supertitle ─────────────────────────────────────────────────────
    sgtitle(sprintf('Stain Detection Debug  |  %d stain(s) detected', numStains), ...
            'Color', 'white', 'FontSize', 13, 'FontWeight', 'bold')

    set(gcf, 'Color', [0.15 0.15 0.15])

end