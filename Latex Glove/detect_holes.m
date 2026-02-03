function [holeMask, holeStats, numHoles] = detect_holes(I, gloveMask)
% DETECT_HOLES Detects holes in latex gloves
%
% Input:
%   I - RGB image of the glove
%   gloveMask - Binary mask of the glove region

    % Convert to double
    I = im2double(I);
    
    % Extract channels
    gray = rgb2gray(I);
    hsv = rgb2hsv(I);
    V = hsv(:,:,3);  % Value channel
    S = hsv(:,:,2);  % Saturation channel
    
    % --- Step 1: Analyze normal glove pixels ---
    gloveGray = gray(gloveMask);
    gloveV = V(gloveMask);
    gloveS = S(gloveMask);
    
    meanGray = mean(gloveGray);
    stdGray = std(gloveGray);
    
    meanV = mean(gloveV);
    stdV = std(gloveV);
    
    meanS = mean(gloveS);

% Method:
%   Holes appear as very dark regions (background showing through)
%   or regions with significantly different color from the glove.
%   Uses intensity thresholding and color deviation analysis.
    
    % --- Step 2: Detect dark regions ---
    % Holes are typically much darker than the glove
    darkThreshold = meanGray - 2.0 * stdGray;
    veryDark = (gray < darkThreshold) & gloveMask;
    
    % Also check value channel
    vDarkThreshold = meanV - 2.5 * stdV;
    veryDarkV = (V < vDarkThreshold) & gloveMask;
    
    % --- Step 3: Detect regions with low saturation ---
    % Holes often show grayish background
    lowSat = (S < (meanS - 0.25)) & gloveMask;
    
    % --- Step 4: Edge-based detection ---
    % Holes have strong edges around them
    edges = edge(gray, 'Canny', [0.05, 0.15]);
    edgesDilated = imdilate(edges, strel('disk', 2));
    
    % --- Step 5: Combine detection methods ---
    holeCandidates = (veryDark | veryDarkV | (lowSat & veryDark)) & edgesDilated & gloveMask;
    
    % --- Step 6: Morphological cleanup ---
    holeMask = imopen(holeCandidates, strel('disk', 2));
    holeMask = imclose(holeMask, strel('disk', 3));
    holeMask = bwareaopen(holeMask, 40);  % Remove very small regions
    
    % --- Step 7: Filter by geometric properties ---
    CC = bwconncomp(holeMask);
    stats = regionprops(CC, 'Area', 'BoundingBox', 'Perimeter', ...
                        'Eccentricity', 'Centroid', 'Solidity');
    
    valid = false(1, numel(stats));
    for i = 1:numel(stats)
        A = stats(i).Area;
        P = stats(i).Perimeter;
        
        % Calculate circularity
        if P > 0
            circularity = 4 * pi * A / (P^2);
        else
            circularity = 0;
        end
        
        % Holes are typically:
        % - Compact (circular-ish)
        % - Reasonable size (40-5000 pixels)
        % - Solid (not too irregular)
        if A >= 40 && A <= 5000 && ...
           circularity > 0.2 && ...
           stats(i).Solidity > 0.4
            valid(i) = true;
        end
    end
    
    % --- Step 8: Generate final outputs ---
    holeMask = ismember(labelmatrix(CC), find(valid));
    holeStats = stats(valid);
    numHoles = nnz(valid);
    
% Output:
%   holeMask - Binary mask of detected holes
%   holeStats - Statistics of detected hole regions
%   numHoles - Number of holes detected
    % Display detection info
    fprintf('Hole Detection Results:\n');
    fprintf('  - Total holes detected: %d\n', numHoles);
    if numHoles > 0
        areas = [holeStats.Area];
        fprintf('  - Average hole size: %.1f pixels\n', mean(areas));
        fprintf('  - Size range: %.0f - %.0f pixels\n', min(areas), max(areas));
    end
end