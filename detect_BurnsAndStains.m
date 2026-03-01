function [burnBoxes, stainBoxes, numBurns, numStains] = detect_BurnsAndStains(img, detectBurns, detectStains)
    % Detection parameters
    PARAMS = struct();
    
    % Color thresholds
    PARAMS.burn_S_max = 0.65;        % Burns: low saturation
    PARAMS.burn_V_max = 0.60;        % Burns: dark value
    
    % Stain: detected by deviation from glove base color (any color stain)
    PARAMS.stain_S_min = 0.20;       % Stains: must have some saturation (not plain gray/white)
    PARAMS.stain_hueDev_min = 0.08;  % Stains: hue deviation from glove base color (0-1 scale)
    PARAMS.stain_V_min = 0.25;       % Stains: not too dark (would be a burn instead)
    
    % Shape thresholds
    PARAMS.burn_solidity_max = 0.85;    % Burns: irregular
    PARAMS.burn_eccent_min = 0.75;      % Burns: elongated
    PARAMS.stain_solidity_min = 0.70;   % Stains: reasonably solid blob
    PARAMS.stain_circular_min = 0.45;   % Stains: somewhat blob-like (relaxed vs holes)
    
    % Texture thresholds
    PARAMS.burn_texture_min = 20;       % Burns: rough texture
    PARAMS.stain_edge_max = 0.20;       % Stains: relatively smooth interior
    
    % Score weights (total = 10)
    PARAMS.weight_color = 4;    % Color is most important for stain detection
    PARAMS.weight_shape = 3;
    PARAMS.weight_texture = 2;
    PARAMS.weight_size = 1;
    
    % Classification threshold
    PARAMS.min_confidence = 3;
    
    % Store original image size
    [origH, ~, ~] = size(img);
    
    % Resize for processing
    img = imresize(img, [1920 NaN]);
    [resizedH, ~, ~] = size(img);
    scaleFactor = origH / resizedH;
    
    % Glove mask
    grayImg = imgaussfilt(rgb2gray(img), 2);
    bwImg = imbinarize(grayImg, graythresh(grayImg));
    bwImg = bwareaopen(bwImg, 2000);
    bwImg = imclose(bwImg, strel('disk', 3));
    filledMask = imfill(bwImg, 'holes');
    filledMask = bwareafilt(filledMask, 1);
    
    % ---------------------------------------------------------------
    % Estimate glove base color in HSV
    % Sample glove pixels: inside mask, not too dark, low-medium saturation
    % ---------------------------------------------------------------
    hsvImg = rgb2hsv(img);
    H = hsvImg(:,:,1);
    S = hsvImg(:,:,2);
    V = hsvImg(:,:,3);
    
    glovePixelsMask = filledMask & (V > 0.3) & (S < 0.5);
    gloveH = H(glovePixelsMask);
    gloveS = S(glovePixelsMask);
    
    if numel(gloveH) > 100
        baseHue = median(gloveH);
        baseS   = median(gloveS);
    else
        % Fallback defaults (assumes light-colored glove)
        baseHue = 0.1;
        baseS   = 0.1;
    end
    
    % Dark candidate mask (same logic as original)
    grayImg(~filledMask) = 255;
    invGray = imcomplement(grayImg);
    invGray = imadjust(invGray, [0.55 0.8], [0 1]);
    candidateMask = invGray > 0.5;
    candidateMask = imopen(candidateMask, strel('disk', 3));
    candidateMask = imclose(candidateMask, strel('disk', 7));
    candidateMask = imfill(candidateMask, 'holes');
    candidateMask = bwareaopen(candidateMask, 200);
    
    % Remove thin shadow-like regions
    distMap = bwdist(~candidateMask);
    thicknessMap = distMap * 2;
    minThickness = 8;
    candidateMask(thicknessMap < minThickness) = 0;
    candidateMask = bwareaopen(candidateMask, 350);
    
    % ---------------------------------------------------------------
    % Stain candidate mask (NEW):
    % Stains are regions inside the glove whose color deviates from
    % the glove base hue AND have visible saturation AND are not dark.
    % This catches paint stains of any color.
    % ---------------------------------------------------------------
    hueDist = abs(H - baseHue);
    hueDist = min(hueDist, 1 - hueDist);  % circular hue distance
    
    stainCandidateMask = filledMask ...
        & (S > PARAMS.stain_S_min) ...
        & (V > PARAMS.stain_V_min) ...
        & (hueDist > PARAMS.stain_hueDev_min);
    
    stainCandidateMask = imopen(stainCandidateMask, strel('disk', 3));
    stainCandidateMask = imclose(stainCandidateMask, strel('disk', 5));
    stainCandidateMask = imfill(stainCandidateMask, 'holes');
    stainCandidateMask = bwareaopen(stainCandidateMask, 200);
    
    % Merge dark candidates (burns) + color candidates (stains)
    combinedMask = candidateMask | stainCandidateMask;
    
    % Extract features
    R = double(img(:,:,1));
    G = double(img(:,:,2));
    B = double(img(:,:,3));
    
    grayNorm = uint8(255 * mat2gray(grayImg));
    
    props = regionprops(combinedMask, 'BoundingBox', 'PixelIdxList', 'Area', ...
        'Solidity', 'Eccentricity', 'Perimeter', 'Circularity');
    
    burnBoxes  = [];
    stainBoxes = [];
    
    % Classification
    for k = 1:length(props)
        % Reject line-like regions
        bb = props(k).BoundingBox;
        aspectRatio = max(bb(3), bb(4)) / min(bb(3), bb(4));
        if aspectRatio > 3.5
            continue;
        end
        
        idx = props(k).PixelIdxList;
        
        % COLOR FEATURES
        meanS  = mean(S(idx));
        meanV  = mean(V(idx));
        meanH  = mean(H(idx));
        
        % Circular hue deviation from glove base
        meanHueDev = abs(meanH - baseHue);
        meanHueDev = min(meanHueDev, 1 - meanHueDev);
        
        % SHAPE FEATURES
        solidity     = props(k).Solidity;
        circularity  = props(k).Circularity;
        eccentricity = props(k).Eccentricity;
        area         = props(k).Area;
        
        % TEXTURE FEATURES
        bb = props(k).BoundingBox;
        bb = round([max(1,bb(1)-5) max(1,bb(2)-5) bb(3)+10 bb(4)+10]);
        bb(3) = min(bb(3), size(img,2)-bb(1)+1);
        bb(4) = min(bb(4), size(img,1)-bb(2)+1);
        
        regionGray = grayNorm(bb(2):bb(2)+bb(4)-1, bb(1):bb(1)+bb(3)-1);
        textureVariance = std(double(regionGray(:)));
        edges = edge(regionGray, 'Canny');
        edgeDensity = sum(edges(:)) / numel(edges);
        
        % SCORING
        burnScore  = 0;
        stainScore = 0;
        
        % --- Color scoring ---
        % Burns: dark + desaturated
        if meanS < PARAMS.burn_S_max && meanV < PARAMS.burn_V_max
            burnScore = burnScore + PARAMS.weight_color;
        end
        
        % Stains: visible saturation + hue different from glove + not too dark
        if meanS > PARAMS.stain_S_min && meanHueDev > PARAMS.stain_hueDev_min && meanV > PARAMS.stain_V_min
            stainScore = stainScore + PARAMS.weight_color;
        end
        % Bonus for highly saturated region (strong paint stain signal)
        if meanS > 0.5
            stainScore = stainScore + 1;
        end
        
        % --- Shape scoring ---
        if solidity < PARAMS.burn_solidity_max || eccentricity > PARAMS.burn_eccent_min
            burnScore = burnScore + PARAMS.weight_shape;
        end
        % Stains: reasonably solid blob shape
        if solidity > PARAMS.stain_solidity_min && circularity > PARAMS.stain_circular_min
            stainScore = stainScore + PARAMS.weight_shape;
        end
        
        % --- Texture scoring ---
        if textureVariance > PARAMS.burn_texture_min
            burnScore = burnScore + PARAMS.weight_texture;
        end
        % Stains tend to have smooth interior (not rough/charred like burns)
        if edgeDensity < PARAMS.stain_edge_max
            stainScore = stainScore + PARAMS.weight_texture;
        end
        
        % --- Size adjustment ---
        if area < 500
            stainScore = stainScore + PARAMS.weight_size;
        elseif area > 1500
            burnScore = burnScore + PARAMS.weight_size;
        end
        
        % CLASSIFICATION
        bb_original = props(k).BoundingBox * scaleFactor;
        
        if detectBurns && burnScore > stainScore && burnScore >= PARAMS.min_confidence
            burnBoxes = [burnBoxes; bb_original];
        elseif detectStains && stainScore > burnScore && stainScore >= PARAMS.min_confidence
            stainBoxes = [stainBoxes; bb_original];
        elseif detectBurns && detectStains
            if burnScore >= PARAMS.min_confidence && burnScore >= stainScore
                burnBoxes = [burnBoxes; bb_original];
            elseif stainScore >= PARAMS.min_confidence && stainScore > burnScore
                stainBoxes = [stainBoxes; bb_original];
            end
        end
    end
    
    numBurns  = size(burnBoxes, 1);
    numStains = size(stainBoxes, 1);
end