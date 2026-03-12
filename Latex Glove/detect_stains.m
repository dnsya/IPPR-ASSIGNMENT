function [stainMask, stainStats, numStains] = detect_stains(I, gloveMask)
% DETECT_STAINS Robust stain detection for glove inspection
%
% INPUT:
%   I         - RGB image
%   gloveMask - binary mask of glove region
%
% OUTPUT:
%   stainMask  - binary mask of detected stains
%   stainStats - region properties of stains
%   numStains  - number of stains detected
    
    %% STEP 1: Preprocessing
    I = im2double(I);
    Igray = rgb2gray(I);
    
    % Remove noise
    Igray = medfilt2(Igray,[3 3]);
    Igray = imgaussfilt(Igray,1.6);
    
    % Remove glove edges
    innerMask = imerode(gloveMask, strel('disk',12));
    
    %% STEP 2: Illumination Normalization
    localMean = imgaussfilt(Igray,25);
    localStd  = imgaussfilt(abs(Igray - localMean),25);
    
    highpass = abs(Igray - localMean) ./ (localStd + eps);
    
    % Model normal glove appearance
    mu = mean(highpass(innerMask),'omitnan');
    sigma = std(highpass(innerMask),'omitnan');
    
    deviationMap = abs(highpass - mu) ./ (sigma + eps);
    
    %% STEP 3: Initial Stain Detection
    stainMask = deviationMap > 2.0;
    stainMask = stainMask & innerMask;
    
    %% STEP 4: Dark Stain Enhancement
    glovePixels = Igray(innerMask);
    
    muGlove = mean(glovePixels);
    sigmaGlove = std(glovePixels);
    
    darkThreshold = muGlove - 1.2*sigmaGlove;
    
    darkPixels = (Igray < darkThreshold) & innerMask;
    
    % Strong dark detector (important for black stains)
    veryDark = (Igray < 0.35) & innerMask;
    
    stainMask = stainMask | darkPixels | veryDark;
    
    %% STEP 5: Wrinkle Suppression (Improved)
    
    [Gmag,~] = imgradient(Igray);
    
    % detect strong gradients
    wrinkleMask = Gmag > prctile(Gmag(innerMask),92);
    
    % clean noise
    wrinkleMask = bwareaopen(wrinkleMask,40);
    
    % analyze shapes
    CCw = bwconncomp(wrinkleMask);
    statsW = regionprops(CCw,'Area','Eccentricity','BoundingBox');
    
    validWrinkle = false(1,numel(statsW));
    
    for i = 1:numel(statsW)
    
        longThin = statsW(i).Eccentricity > 0.95;
        mediumArea = statsW(i).Area > 40 && statsW(i).Area < 3000;
    
        if longThin && mediumArea
            validWrinkle(i) = true;
        end
    
    end
    
    wrinkleMask = ismember(labelmatrix(CCw), find(validWrinkle));
    
    % remove wrinkles from stain mask
    stainMask = stainMask & ~wrinkleMask;
    
    %% STEP 6: Morphological Cleanup
    stainMask = imopen(stainMask, strel('disk',8));
    stainMask = imclose(stainMask, strel('disk',3));
    
    % Remove tiny noise
    stainMask = bwareaopen(stainMask,1000);
    
    % Fill holes inside stains
    stainMask = imfill(stainMask,'holes');
    
    
    
    %% STEP 7: Reflection Detection
    reflectionMask = Igray > prctile(Igray(innerMask),99);
    
    % reflections usually have low saturation
    hsv = rgb2hsv(I);
    S = hsv(:,:,2);
    
    reflectionMask = reflectionMask & S < 0.2;
    
    % REMOVE reflections
    stainMask = stainMask & ~reflectionMask;
    
    %% STEP 8: Region Filtering
    CC = bwconncomp(stainMask);
    
    stats = regionprops(CC,Igray,...
        'Area','BoundingBox','Centroid','Eccentricity','Solidity','MeanIntensity');
    
    % Convert to HSV for color comparison
    Ihsv = rgb2hsv(I);
    
    H = Ihsv(:,:,1);
    S = Ihsv(:,:,2);
    V = Ihsv(:,:,3);
    
    meanH = mean(H(innerMask),'omitnan');
    meanS = mean(S(innerMask),'omitnan');
    meanV = mean(V(innerMask),'omitnan');
    
    valid = false(1,numel(stats));
    
    for i = 1:numel(stats)
    
        areaOK = stats(i).Area >= 200 && stats(i).Area <= 20000;
        shapeOK = stats(i).Eccentricity < 0.97 && stats(i).Solidity > 0.45;
    
        regionMask = ismember(labelmatrix(CC),i);
    
        hMean = mean(H(regionMask));
        sMean = mean(S(regionMask));
        vMean = mean(V(regionMask));
    
        % simpler color difference
        colorDist = abs(hMean-meanH) + ...
                    abs(sMean-meanS) + ...
                    abs(vMean-meanV);
    
        if areaOK && shapeOK && colorDist > 0.15
            valid(i) = true;
        end
    end
    
    %% STEP 9: Final Output
    stainMask = ismember(labelmatrix(CC),find(valid));
    stainStats = stats(valid);
    numStains = sum(valid);
    
    fprintf('Stain Detection: Found %d stain(s)\n', numStains);
    
    %% STEP 10: Debug Visualization
    figure('Name','Stain Detection Debug','NumberTitle','off');
    
    subplot(2,3,1)
    imshow(Igray)
    title('Preprocessed Grayscale')
    
    subplot(2,3,2)
    imshow(deviationMap,[])
    title('Deviation Map')
    
    subplot(2,3,3)
    imshow(stainMask)
    title('Final Stain Mask')
    
    subplot(2,3,4)
    imshow(wrinkleMask)
    title('Wrinkle Mask')
    
    subplot(2,3,5)
    imshow(I)
    hold on
    for i = 1:numStains
        rectangle('Position',stainStats(i).BoundingBox,...
            'EdgeColor','y','LineWidth',2)
    end
    title(['Detected Stains: ',num2str(numStains)])
    hold off
    
    subplot(2,3,6)
    imshow(darkPixels)
    title('Dark Pixels')
end
