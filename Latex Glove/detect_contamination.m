function [contamMask, contamStats, numContam] = detect_contamination(I, gloveMask)
% DETECT_CONTAMINATION Detects contamination (foreign objects) on a latex glove
%
% INPUT:
%   I         - RGB image of the glove
%   gloveMask - binary mask of glove region
%
% OUTPUT:
%   contamMask  - binary mask of detected contamination
%   contamStats - regionprops of detected contamination
%   numContam   - number of contamination regions

    %% STEP 1: Preprocessing
    Iproc = im2double(I);
    gray = rgb2gray(Iproc);
    hsv = rgb2hsv(Iproc);
    H = hsv(:,:,1);
    S = hsv(:,:,2);
    V = hsv(:,:,3);

    %% STEP 2: Focus only on glove
    % Mask outside glove
    gray(~gloveMask) = 0;
    H(~gloveMask) = 0;
    S(~gloveMask) = 0;
    V(~gloveMask) = 0;
    

    %% STEP 3: Detect regions statistically different from glove
    
    % Inner glove region (avoid edges & background bleed)
    innerMask = imerode(gloveMask, strel('disk',12));
    
    % --- Intensity (grayscale) model ---
    muGray = mean(gray(innerMask), 'omitnan');
    sigmaGray = std(gray(innerMask), 'omitnan');
    
    intensityDiff = abs(gray - muGray) > 1.6 * sigmaGray;
    
    % --- Color (HSV) model ---
    muH = mean(H(innerMask), 'omitnan');
    muS = mean(S(innerMask), 'omitnan');
    muV = mean(V(innerMask), 'omitnan');
    
    colorDiff = abs(H - muH) + abs(S - muS) + abs(V - muV);
    colorOutlier = colorDiff > 0.35;

    % --- Combine deviation cues ---
    rawMask = (intensityDiff | colorOutlier) & innerMask;
    
    %% STEP 4: Morphological cleanup
    rawMask = imopen(rawMask, strel('disk',5));    % remove speckle noise
    rawMask = imclose(rawMask, strel('disk',6));   % fill object gaps
    rawMask = bwareaopen(rawMask, 5000);            % remove tiny blobs
    

    %% STEP 5: Analyze connected components
    CC = bwconncomp(rawMask);
    stats = regionprops(CC, 'Area', 'Centroid', 'BoundingBox', 'Eccentricity', 'Solidity');

    % Filter regions by area/shape to remove small artifacts
    valid = false(1, numel(stats));
    for i = 1:numel(stats)
        if stats(i).Area > 300 && stats(i).Area < 20000 && stats(i).Solidity > 0.2
            valid(i) = true;
        end
    end

    %% STEP 6: Generate outputs
    contamMask = ismember(labelmatrix(CC), find(valid));
    contamStats = stats(valid);
    numContam = sum(valid);

    %% STEP 7: Optional: visualize
    if numContam > 0
        figure; imshow(I); hold on;
        for i = 1:numContam
            bbox = contamStats(i).BoundingBox;
            rectangle('Position', bbox, 'EdgeColor', 'r', 'LineWidth', 2);
            text(bbox(1), bbox(2)-10, sprintf('Contam %d', i), 'Color', 'red', 'FontWeight','bold');
        end
        hold off;
    end

    %fprintf('Contamination Detection: Found %d region(s)\n', numContam);
    figure;
    subplot(1,3,1), imshow(intensityDiff), title('Intensity Diff');
    subplot(1,3,2), imshow(colorOutlier), title('Color Outlier');
    subplot(1,3,3), imshow(rawMask), title('Final Raw Mask');

end
