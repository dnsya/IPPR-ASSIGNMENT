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
    colorOutlier = colorDiff > 0.35;

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
    rawMask = bwareaopen(rawMask, 2000);             % Remove small fragments

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
        areaOK   = stats(i).Area > 300 && stats(i).Area < 40000;
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
    figure('Name', 'Contamination Detection Debug', 'NumberTitle', 'off');

    subplot(2, 3, 1)
    imshow(gray, [])
    title('Grayscale (glove region only)')

    subplot(2, 3, 2)
    imshow(intensityDiff)
    title('Intensity Deviation')

    subplot(2, 3, 3)
    imshow(colorOutlier)
    title('Colour Outlier')

    subplot(2, 3, 4)
    imshow(rawMask)
    title('Raw Mask (after morphology)')

    subplot(2, 3, 5)
    imshow(I)
    hold on
    for i = 1:numContam
        rectangle('Position', contamStats(i).BoundingBox, ...
                  'EdgeColor', 'r', 'LineWidth', 2)
        text(contamStats(i).BoundingBox(1), ...
             contamStats(i).BoundingBox(2) - 10, ...
             sprintf('C%d', i), 'Color', 'r', 'FontWeight', 'bold')
    end
    title(['Detected Contamination: ' num2str(numContam)])
    hold off

    subplot(2, 3, 6)
    imshow(contamMask)
    title('Final Contamination Mask')

end