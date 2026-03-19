function [contamMask, contamStats, numContam] = detect_contamination(I, gloveMask)
% DETECT_CONTAMINATION  Detects contamination (foreign objects) on a latex glove.
%
% Contamination refers to any foreign material on the glove surface that is
% statistically different from the normal glove colour and texture — for
% example, rubber bands, strings, dirt, or residue.
%
% INPUT:
%   I         - RGB image of the glove (uint8 or double)
%   gloveMask - Binary mask of the glove region (from segment_glove_hsv)
%
% OUTPUT:
%   contamMask  - Binary mask of detected contamination regions
%   contamStats - regionprops struct array for each detected region
%   numContam   - Number of contamination regions detected

    %% ---------------------------------------------------------------
    %  STEP 1: Preprocessing — convert to double and extract channels
    %% ---------------------------------------------------------------
    Iproc = im2double(I);
    gray  = rgb2gray(Iproc);
    hsv   = rgb2hsv(Iproc);
    H     = hsv(:,:,1);    % Hue
    S     = hsv(:,:,2);    % Saturation
    V     = hsv(:,:,3);    % Value (brightness)

    %% ---------------------------------------------------------------
    %  STEP 2: Restrict analysis to the glove region
    %  Pixels outside the glove mask are zeroed so they cannot influence
    %  the statistical model or trigger false detections.
    %% ---------------------------------------------------------------
    gray(~gloveMask) = 0;
    H(~gloveMask)    = 0;
    S(~gloveMask)    = 0;
    V(~gloveMask)    = 0;

    %% ---------------------------------------------------------------
    %  STEP 3: Statistical deviation detection
    %  An inner erosion avoids glove-edge pixels which can be noisy.
    %  Pixels whose intensity or colour deviates significantly from the
    %  mean glove appearance are flagged as potential contamination.
    %% ---------------------------------------------------------------
    innerMask = imerode(gloveMask, strel('disk', 12));

    % --- Grayscale intensity model ---
    muGray    = mean(gray(innerMask), 'omitnan');
    sigmaGray = std(gray(innerMask),  'omitnan');

    intensityDiff = abs(gray - muGray) > 1.6 * sigmaGray;

    % --- HSV colour model ---
    muH = mean(H(innerMask), 'omitnan');
    muS = mean(S(innerMask), 'omitnan');
    muV = mean(V(innerMask), 'omitnan');

    colorDiff    = abs(H - muH) + abs(S - muS) + abs(V - muV);
    colorOutlier = colorDiff > 0.36;

    % Combine both cues: a pixel is suspicious if it deviates in either
    % intensity or colour, and lies within the inner glove region.
    rawMask = (intensityDiff | colorOutlier) & innerMask;

    %% ---------------------------------------------------------------
    %  STEP 4: Morphological cleanup
    %  imopen removes speckle noise; imclose (disk 8) bridges the gaps
    %  that appear in arc-shaped objects such as rubber bands; bwareaopen
    %  discards small fragments that survive after the closing step.
    %% ---------------------------------------------------------------
    rawMask = imopen(rawMask,  strel('disk', 5));   % Remove speckle noise
    rawMask = imclose(rawMask, strel('disk', 8));   % Bridge gaps in ring shapes
    rawMask = bwareaopen(rawMask, 5000);             % Remove small fragments

    %% ---------------------------------------------------------------
    %  STEP 5: Connected-component analysis and region filtering
    %  Each candidate region is evaluated by area and solidity.
    %  The upper area limit is 40 000 px to accommodate large objects
    %  such as a rubber band around the wrist.
    %% ---------------------------------------------------------------
    CC    = bwconncomp(rawMask);
    stats = regionprops(CC, 'Area', 'Centroid', 'BoundingBox', ...
                            'Eccentricity', 'Solidity');

    valid = false(1, numel(stats));

    for i = 1:numel(stats)
        areaOK   = stats(i).Area > 7801 && stats(i).Area < 30000;
        solidOK  = stats(i).Solidity > 0.2;
        valid(i) = areaOK && solidOK;
    end

    %% ---------------------------------------------------------------
    %  STEP 6: Build final outputs
    %% ---------------------------------------------------------------
    contamMask  = ismember(labelmatrix(CC), find(valid));
    contamStats = stats(valid);
    numContam   = sum(valid);

    fprintf('Contamination Detection: Found %d region(s)\n', numContam);

    %% ---------------------------------------------------------------
    %  STEP 7: Debug visualisation — 6-panel figure
    %% ---------------------------------------------------------------

    figure('Name', 'Contamination Detection Debug', 'NumberTitle', 'off', ...
           'Color', [0.15 0.15 0.15], 'Position', [100 100 1200 700]);

    % ── Panel 1: Grayscale (glove region only) ────────────────────────────────
    subplot(2, 3, 1)
    imshow(gray, [])
    title('1. Grayscale (glove region only)', ...
          'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold')
    set(gca, 'Color', [0.15 0.15 0.15])

    % ── Panel 2: Intensity Deviation ─────────────────────────────────────────
    subplot(2, 3, 2)
    imshow(intensityDiff)
    title('2. Intensity Deviation', ...
          'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold')
    set(gca, 'Color', [0.15 0.15 0.15])

    % ── Panel 3: Colour Outlier ───────────────────────────────────────────────
    subplot(2, 3, 3)
    imshow(colorOutlier)
    title('3. Colour Outlier', ...
          'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold')
    set(gca, 'Color', [0.15 0.15 0.15])

    % ── Panel 4: Raw Mask after morphology ────────────────────────────────────
    subplot(2, 3, 4)
    imshow(rawMask)
    title('4. Raw Mask (after morphology)', ...
          'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold')
    set(gca, 'Color', [0.15 0.15 0.15])

    % ── Panel 5: Annotated Original ───────────────────────────────────────────
    subplot(2, 3, 5)
    imshow(I)
    hold on
    for i = 1:numContam
        bb = contamStats(i).BoundingBox;

        % Bounding box
        rectangle('Position', bb, 'EdgeColor', [1 0.5 0], 'LineWidth', 2)

        % Centroid marker
        cx = bb(1) + bb(3)/2;
        cy = bb(2) + bb(4)/2;
        plot(cx, cy, '+', 'Color', [1 0.5 0], ...
             'MarkerSize', 12, 'LineWidth', 2)

        % Label with area
        text(bb(1), bb(2) - 6, sprintf('C%d  (%.0f px)', i, contamStats(i).Area), ...
             'Color', [1 0.5 0], 'FontSize', 9, 'FontWeight', 'bold', ...
             'BackgroundColor', [0 0 0 0.5])
    end

    if numContam == 0
        titleStr = 'Detected Contamination: None';
        titleCol = [0.6 1.0 0.6];   % green — clean glove
    else
        titleStr = sprintf('Detected Contamination: %d', numContam);
        titleCol = [1.0 0.6 0.2];   % orange — contamination found
    end

    title(titleStr, 'Color', titleCol, 'FontSize', 11, 'FontWeight', 'bold')
    hold off
    set(gca, 'Color', [0.15 0.15 0.15])

    % ── Panel 6: Final Contamination Mask ────────────────────────────────────
    subplot(2, 3, 6)
    imshow(contamMask)
    title('6. Final Contamination Mask', ...
          'Color', 'white', 'FontSize', 11, 'FontWeight', 'bold')
    set(gca, 'Color', [0.15 0.15 0.15])

    % ── Figure supertitle ─────────────────────────────────────────────────────
    sgtitle(sprintf('Contamination Detection Debug  |  %d region(s) detected', numContam), ...
            'Color', 'white', 'FontSize', 13, 'FontWeight', 'bold')

    set(gcf, 'Color', [0.15 0.15 0.15])

end