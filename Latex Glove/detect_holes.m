function [holeMask, holeStats, numHoles] = detect_holes(I, gloveMask)
% DETECT_HOLES Detects holes in latex gloves
%
% Input:
%   I - RGB image of the glove
%   gloveMask - Binary mask of the glove region
    % Convert to double
    Iproc = im2double(I);
    
    % Extract channels
    gray = rgb2gray(Iproc);
    hsv = rgb2hsv(Iproc);
    H = hsv(:, :, 1);  % Hue
    V = hsv(:,:,3);  % Value channel
    S = hsv(:,:,2);  % Saturation channel

    rawMask = (H > 0.49 & H < 0.7) & (S > 0.4);

    % close wrinkles
    rawMask = imclose(rawMask, strel("disk",8));   
    % remove thin noise
    rawMask = imopen(rawMask, strel("disk",3));    
    % remove noise
    rawMask = bwareaopen(rawMask, 3000); 

    unfilledMask = rawMask;
    
    filledMask  = imfill(rawMask, 'holes');
    
    holeMask = gloveMask & filledMask & ~unfilledMask;
    
    holeMask = bwareaopen(holeMask, 50);
    
    
    % --- Step 2
    % Holes are enclosed voids inside the glove region

    % Analyze hole properties
    CC = bwconncomp(holeMask);
    stats = regionprops(CC, ...
    'Area', 'Centroid', 'BoundingBox', 'Eccentricity');

    
    if ~isempty(stats)
        validHoles = ([stats.Area] > 50) & ([stats.Area] < 5000);
        
        % Count valid holes
        numHoles = sum(validHoles);
        fprintf('Number of holes detected: %d\n', numHoles);
        
        % Display hole information
        for i = 1:length(stats)
            if validHoles(i)
                fprintf('Hole %d: Area = %.0f pixels, Centroid = (%.1f, %.1f)\n', ...
                        i, stats(i).Area, stats(i).Centroid(1), stats(i).Centroid(2));
            end
        end
    else
        numHoles = 0;
        fprintf('No holes detected.\n');
    end
    
    if numHoles > 0
        hold on;
        for i = 1:length(stats)
            if validHoles(i)
                plot(stats(i).Centroid(1), stats(i).Centroid(2), ...
                     'r+', 'MarkerSize', 15, 'LineWidth', 2);
                text(stats(i).Centroid(1) + 20, stats(i).Centroid(2), ...
                     sprintf('H%d', i), 'Color', 'red', 'FontWeight', 'bold');
            end
        end
        hold off;
    end
    

    % --- Step 8: Generate final outputs ---
    holeMask = ismember(labelmatrix(CC), find(validHoles));
    holeStats = stats(validHoles);
    numHoles = nnz(validHoles);
    
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