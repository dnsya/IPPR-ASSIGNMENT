function [stainMask, stainStats, numStains] = detect_stains(I, gloveMask)
% DETECT_STAINS Robust stain detection with enhanced noise removal

% DETECT_STAINS Detects discoloration and stains on glove surface
%
% INPUT:
%   I         - RGB image
%   gloveMask - binary mask of glove region

    %% STEP 1: Preprocessing 
    I = im2double(I);
    Igray = rgb2gray(I);

    % median filter for speckle / sensor noise
    Igray = medfilt2(Igray, [3 3]);

    % slightly stronger smoothing
    Igray = imgaussfilt(Igray, 1.6);

    %% STEP 2: Remove glove edges
    innerMask = imerode(gloveMask, strel('disk', 12));

    %% STEP 3: Remove illumination (UNCHANGED)
    %background = imgaussfilt(Igray, 25);
    %highpass = abs(Igray - background);

    localMean = imgaussfilt(Igray, 25);     
    localStd  = imgaussfilt(abs(Igray - localMean), 25);  

    highpass = abs(Igray - localMean) ./ (localStd + eps);

    %% STEP 4: Model normal glove appearance
    mu = mean(highpass(innerMask), 'omitnan');
    sigma = std(highpass(innerMask), 'omitnan');

    deviationMap = abs(highpass - mu) / (sigma + eps);

    %% STEP 5: Initial stain detection
    stainMask = deviationMap > 2.0;
    stainMask = stainMask & innerMask;

    % Dark/wet stain boost
    gloveOnly = Igray .* innerMask;  

    muGlove = mean(gloveOnly(innerMask), 'omitnan');
    sigmaGlove = std(gloveOnly(innerMask), 'omitnan');

    % Threshold for pixels significantly darker than glove average
    darkThreshold = muGlove - 1.2*sigmaGlove;  
    darkPixels = (gloveOnly < darkThreshold) & innerMask;
    
    % Combine with existing stain mask
    stainMask = stainMask | darkPixels;

    %% STEP 6: Wrinkle suppression 
    [Gmag, ~] = imgradient(Igray);

    wrinkleMask = Gmag > prctile(Gmag(innerMask), 90);
    wrinkleMask = imopen(wrinkleMask, strel('line', 15, 0)) | ...
                  imopen(wrinkleMask, strel('line', 15, 90));

    stainMask = stainMask & ~wrinkleMask;

    %% STEP 7: Morphological cleanup 
    stainMask = imopen(stainMask, strel('disk', 3));   
    stainMask = imclose(stainMask, strel('disk', 6));

    % Threshold for bright pixels (likely specular highlights)
    reflectionMask = Igray > prctile(Igray(innerMask), 99);  
    reflectionMask = reflectionMask & innerMask;

    stainDilated = imdilate(stainMask, strel('disk', 3));
    reflectionMask = reflectionMask & stainDilated;

    stainMask = stainMask | reflectionMask;

    % ADDED: fill small holes inside stains
    stainMask = imfill(stainMask, 'holes');

    % ADDED: remove small isolated noise
    stainMask = bwareaopen(stainMask, 300);

    % Remove small isolated objects
    stainMask = bwareaopen(stainMask, 500);  
    
    % Optional: smooth edges to remove thin lines
    stainMask = imopen(stainMask, strel('disk', 4));

    %% STEP 8: Region filtering 
    CC = bwconncomp(stainMask);
    stats = regionprops(CC, Igray, ...
        'Area', 'BoundingBox', 'Centroid', ...
        'Eccentricity', 'Solidity', 'MeanIntensity');
    Ihsv = rgb2hsv(I);

    H = Ihsv(:,:,1);
    S = Ihsv(:,:,2);
    V = Ihsv(:,:,3);
    
    meanH = mean(H(innerMask), 'omitnan');
    meanS = mean(S(innerMask), 'omitnan');
    meanV = mean(V(innerMask), 'omitnan');

    valid = false(1, numel(stats));
    
    for i = 1:numel(stats)
        areaOK = stats(i).Area >= 300 && stats(i).Area <= 20000;
        shapeOK = stats(i).Eccentricity < 0.95 && stats(i).Solidity > 0.5;
    
        % Get region mask
        regionMask = ismember(labelmatrix(CC), i);
    
        % Mean HSV of region
        hMean = mean(H(regionMask));
        sMean = mean(S(regionMask));
        vMean = mean(V(regionMask));
    
        % COLOR DIFFERENCE check
        colorDist = abs(hMean - meanH) + ...
                    abs(sMean - meanS) + ...
                    abs(vMean - meanV);
    
        if areaOK && shapeOK && colorDist > 0.6 * mean([meanH meanS meanV])
            valid(i) = true;   % real stain
        end
    end

% OUTPUT:
%   stainMask  - binary mask of stains
%   stainStats - regionprops of detected stains
%   numStains  - number of stains    

    stainMask = ismember(labelmatrix(CC), find(valid));
    stainStats = stats(valid);
    numStains = sum(valid);

    fprintf('Stain Detection: Found %d stain(s)\n', numStains);
end
