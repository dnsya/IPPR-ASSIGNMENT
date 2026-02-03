function [contamMask, contamStats, numContam] = detect_contamination(I, gloveMask)
% DETECT_CONTAMINATION Detects foreign objects on glove surface
% IMPROVED VERSION - Better discrimination from stains
% Targets: rubber bands, strings, wires, plastic pieces (NOT stains)
%
% INPUT:
%   I         - RGB image
%   gloveMask - binary mask of glove region


    %% STEP 1: Preprocessing
    I = im2double(I);
    Igray = rgb2gray(I);
    Igray = imgaussfilt(Igray, 1.2);

    %% STEP 2: Work on inner glove area (exclude edges)
    innerMask = imerode(gloveMask, strel('disk', 12));
    Igray(~innerMask) = NaN;

    %% STEP 3: Get glove color statistics
    Ihsv = rgb2hsv(I);
    H = Ihsv(:,:,1);
    S = Ihsv(:,:,2);
    V = Ihsv(:,:,3);
    
    R = I(:,:,1);
    G = I(:,:,2);
    B = I(:,:,3);
    
    meanH = mean(H(innerMask), 'omitnan');
    meanS = mean(S(innerMask), 'omitnan');
    meanV = mean(V(innerMask), 'omitnan');
    meanR = mean(R(innerMask), 'omitnan');
    meanG = mean(G(innerMask), 'omitnan');
    meanB = mean(B(innerMask), 'omitnan');

    %% STEP 4: Detect STRONGLY COLORED objects (rubber bands) - PRIMARY METHOD
    colorDistHSV = abs(H - meanH) + abs(S - meanS) + abs(V - meanV);
    colorDistRGB = sqrt((R - meanR).^2 + (G - meanG).^2 + (B - meanB).^2);
    
    % HIGH saturation objects (colored items like orange rubber bands)
    highSaturation = S > 0.35;  % Increased from 0.25 - be more selective
    
    % STRONG color difference (not subtle like stains)
    strongColorMaskHSV = colorDistHSV > 0.30;  % Increased from 0.20
    strongColorMaskRGB = colorDistRGB > 0.20;  % Increased from 0.15
    
    % Colored object mask (PRIMARY for rubber bands, colored contamination)
    coloredObjectMask = (strongColorMaskHSV & strongColorMaskRGB) | highSaturation;
    coloredObjectMask = coloredObjectMask & innerMask;

    %% STEP 5: Edge detection for strings/wires (SECONDARY METHOD)
    [Gmag, ~] = imgradient(Igray);
    edgeThresh = prctile(Gmag(innerMask), 88);  % Higher threshold
    
    % Canny edge detection for thin objects
    BWedge = edge(Igray, 'Canny', [0.08 0.18]);  % Stricter thresholds
    BWedge = BWedge & innerMask;
    BWedge = imdilate(BWedge, strel('disk', 2));
    BWedge = imclose(BWedge, strel('disk', 3));
    BWthin = bwmorph(BWedge, 'skel', Inf);
    BWthin = bwareaopen(BWthin, 80);  % Increased from 60

    %% STEP 6: Combine detection methods
    % Colored objects OR thin edge objects (strings/wires)
    contamMask = coloredObjectMask | BWthin;

    %% STEP 7: Remove wrinkles (linear patterns)
    wrinkleMask = Gmag > prctile(Gmag(innerMask), 90);
    wrinkleMask = imopen(wrinkleMask, strel('line', 10, 0)) | ...
                  imopen(wrinkleMask, strel('line', 10, 45)) | ...
                  imopen(wrinkleMask, strel('line', 10, 90)) | ...
                  imopen(wrinkleMask, strel('line', 10, 135));
    wrinkleMask = imdilate(wrinkleMask, strel('disk', 4));
    
    contamMask = contamMask & ~wrinkleMask;

    %% STEP 8: Morphological cleanup
    contamMask = imclose(contamMask, strel('disk', 6));  % Increased from 5
    contamMask = bwareaopen(contamMask, 180);  % Increased from 120

    %% STEP 9: STRICT region filtering to exclude stains
    CC = bwconncomp(contamMask);
    stats = regionprops(CC, Igray, ...
        'Area', 'BoundingBox', 'Centroid', ...
        'Eccentricity', 'Solidity', 'MeanIntensity', 'Perimeter', 'Extent');

    valid = false(1, numel(stats));
    meanGloveIntensity = mean(Igray(innerMask), 'omitnan');

    for i = 1:numel(stats)
        regionMask = ismember(labelmatrix(CC), i);
        
        % Area check - contamination is usually smaller than large stains
        areaOK = stats(i).Area > 180 && stats(i).Area < 12000;  % Tighter range
        
        % Shape analysis
        if stats(i).Perimeter > 0
            compactness = 4 * pi * stats(i).Area / (stats(i).Perimeter^2);
        else
            compactness = 0;
        end
        
        % Contamination characteristics:
        % - Rubber bands: VERY elongated (high eccentricity)
        % - Strings: VERY elongated, low compactness
        % - Should NOT be blob-like (stains are blob-like)
        isVeryElongated = stats(i).Eccentricity > 0.85;  % Increased from 0.80
        isString = compactness > 0.03 && compactness < 0.15;  % Stricter range
        
        % Exclude blob-like shapes (likely stains)
        isBlobLike = compactness > 0.30 && stats(i).Eccentricity < 0.70;
        
        shapeOK = (isVeryElongated || isString) && ~isBlobLike;
        
        % Color analysis - contamination has STRONG color difference
        regionH = mean(H(regionMask), 'omitnan');
        regionS = mean(S(regionMask), 'omitnan');
        regionV = mean(V(regionMask), 'omitnan');
        regionR = mean(R(regionMask), 'omitnan');
        regionG = mean(G(regionMask), 'omitnan');
        regionB = mean(B(regionMask), 'omitnan');
        
        colorDistHSV_region = abs(regionH - meanH) + ...
                              abs(regionS - meanS) + ...
                              abs(regionV - meanV);
        
        colorDistRGB_region = sqrt((regionR - meanR)^2 + ...
                                   (regionG - meanG)^2 + ...
                                   (regionB - meanB)^2);
        
        % STRONG color difference (much more than subtle stains)
        hasVeryStrongColor = (colorDistHSV_region > 0.25) && (colorDistRGB_region > 0.18);
        
        % HIGH saturation (rubber bands are vibrant)
        hasVeryHighSaturation = regionS > 0.35;
        
        % Is it a CLEARLY colored foreign object?
        isStronglyColoredObject = hasVeryStrongColor || hasVeryHighSaturation;
        
        % Edge strength - contamination has sharp, defined edges
        edgeStrength = mean(Gmag(regionMask), 'omitnan');
        hasSharpEdges = edgeStrength > edgeThresh * 0.70;
        
        % Check for thin rigid objects (strings, wires)
        edgePixels = sum(BWthin(regionMask));
        edgeRatio = edgePixels / stats(i).Area;
        isThinRigidObject = edgeRatio > 0.30 && stats(i).Eccentricity > 0.80;
        
        % Texture check - stains have low texture, contamination has more variation
        localStdDev = std(Igray(regionMask), 'omitnan');
        hasTexture = localStdDev > 0.04;  % Contamination has more texture than stains
        
        % EXCLUDE stain characteristics:
        % - Subtle color change
        % - Soft edges
        % - Low texture
        % - Blob-like shape
        subtleColor = colorDistHSV_region < 0.20 && colorDistRGB_region < 0.15;
        softEdges = edgeStrength < prctile(Gmag(innerMask), 70);
        lowTexture = localStdDev < 0.05;
        
        isLikelyStain = subtleColor && softEdges && lowTexture && isBlobLike;

        % DECISION LOGIC - contamination must be:
        % 1. Right size and shape
        % 2. Either: strongly colored OR thin rigid object
        % 3. Has sharp edges or texture
        % 4. NOT a stain
        
        if areaOK && shapeOK && ~isLikelyStain && ...
           (isThinRigidObject || isStronglyColoredObject) && ...
           (hasSharpEdges || hasTexture)
            valid(i) = true;
        end
    end

% OUTPUT:
%   contamMask  - binary mask of contamination
%   contamStats - regionprops of detected contamination
%   numContam   - number of contamination objects

    %% STEP 10: Final contamination mask
    contamMask = ismember(labelmatrix(CC), find(valid));
    contamStats = stats(valid);
    numContam = sum(valid);

    fprintf('Contamination Detection: Found %d object(s)\n', numContam);
end