function [burnBoxes, holeBoxes, numBurns, numHoles] = detect_BurnsAndHoles(img, detectBurns, detectHoles)
% DETECT_BURNSANDHOLES Detects and classifies burn marks and holes in glove images
%
% Syntax:
%   [burnBoxes, holeBoxes, numBurns, numHoles] = detect_BurnsAndHoles(img, detectBurns, detectHoles)
%
% Inputs:
%   img - RGB image of the glove
%   detectBurns - Boolean flag to detect burn marks
%   detectHoles - Boolean flag to detect holes
%
% Outputs:
%   burnBoxes - Nx4 matrix of burn bounding boxes [x, y, width, height]
%   holeBoxes - Nx4 matrix of hole bounding boxes [x, y, width, height]
%   numBurns - Number of burn marks detected
%   numHoles - Number of holes detected
%
% Algorithm:
%   1. Creates glove mask and identifies dark candidate regions
%   2. Extracts color (HSV), shape, and texture features for each region
%   3. Uses scoring system to classify regions as burns or holes
%   4. Returns appropriate detections based on user flags
%
% Classification Features:
%   BURNS: Low saturation, dark value, irregular shape, rough texture, larger
%   HOLES: High saturation, reddish, circular shape, sharp edges, smaller

    % Detection parameters
    PARAMS = struct();
    
    % Color thresholds
    PARAMS.burn_S_max = 0.65;        % Burns: low saturation
    PARAMS.burn_V_max = 0.60;        % Burns: dark value
    PARAMS.hole_S_min = 0.65;        % Holes: higher saturation
    PARAMS.hole_redRatio_min = 1.10; % Holes: more reddish
    
    % Shape thresholds
    PARAMS.burn_solidity_max = 0.85;    % Burns: irregular
    PARAMS.burn_eccent_min = 0.75;      % Burns: elongated
    PARAMS.hole_circular_min = 0.65;    % Holes: more circular
    PARAMS.hole_solidity_min = 0.88;    % Holes: solid shape
    
    % Texture thresholds
    PARAMS.burn_texture_min = 20;       % Burns: rough texture
    PARAMS.hole_edge_min = 0.12;        % Holes: sharp edges
    
    % Score weights (total = 10)
    PARAMS.weight_color = 3;
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
    
    % Dark candidate mask
    grayGlove = rgb2gray(img);
    grayGlove(~filledMask) = 255;
    invGray = imcomplement(grayGlove);
    invGray = imadjust(invGray, [0.55 0.8], [0 1]);
    candidateMask = invGray > 0.5;
    candidateMask = imopen(candidateMask, strel('disk', 3));
    candidateMask = imclose(candidateMask, strel('disk', 7));
    candidateMask = imfill(candidateMask, 'holes');
    candidateMask = bwareaopen(candidateMask, 200);

    % --- Remove thin shadow-like regions (thickness filtering) ---
    distMap = bwdist(~candidateMask);
    thicknessMap = distMap * 2;   % approximate local thickness
    
    minThickness = 8;
    candidateMask(thicknessMap < minThickness) = 0;
    candidateMask = bwareaopen(candidateMask, 350);

    
    % Extract features
    R = double(img(:,:,1));
    G = double(img(:,:,2));
    B = double(img(:,:,3));
    hsvImg = rgb2hsv(img);
    S = hsvImg(:,:,2);
    V = hsvImg(:,:,3);
    
    grayNorm = uint8(255 * mat2gray(grayGlove));
    
    props = regionprops(candidateMask, 'BoundingBox', 'PixelIdxList', 'Area', ...
        'Solidity', 'Eccentricity', 'Perimeter', 'Circularity');
    
    burnBoxes = [];
    holeBoxes = [];
    
    % Classification
    for k = 1:length(props)
        % --- Reject crease / line-like shadows ---
        bb = props(k).BoundingBox;
        aspectRatio = max(bb(3), bb(4)) / min(bb(3), bb(4));
        
        % Line-like region → skip
        if aspectRatio > 3.5
            continue;
        end

        idx = props(k).PixelIdxList;
        
        % COLOR FEATURES
        meanR = mean(R(idx));
        meanG = mean(G(idx));
        meanB = mean(B(idx));
        meanS = mean(S(idx));
        meanV = mean(V(idx));
        redRatio = meanR / (meanG + meanB + eps);
        
        % SHAPE FEATURES
        solidity = props(k).Solidity;
        circularity = props(k).Circularity;
        eccentricity = props(k).Eccentricity;
        area = props(k).Area;
        
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
        burnScore = 0;
        holeScore = 0;
        
        % Color scoring
        if meanS < PARAMS.burn_S_max && meanV < PARAMS.burn_V_max
            burnScore = burnScore + PARAMS.weight_color;
        end
        if meanS > PARAMS.hole_S_min && redRatio > PARAMS.hole_redRatio_min
            holeScore = holeScore + PARAMS.weight_color;
        end
        
        % Shape scoring
        if solidity < PARAMS.burn_solidity_max || eccentricity > PARAMS.burn_eccent_min
            burnScore = burnScore + PARAMS.weight_shape;
        end
        if circularity > PARAMS.hole_circular_min && solidity > PARAMS.hole_solidity_min
            holeScore = holeScore + PARAMS.weight_shape;
        end
        
        % Texture scoring
        if textureVariance > PARAMS.burn_texture_min
            burnScore = burnScore + PARAMS.weight_texture;
        end
        if edgeDensity > PARAMS.hole_edge_min
            holeScore = holeScore + PARAMS.weight_texture;
        end
        
        % Size adjustment
        if area < 500
            holeScore = holeScore + PARAMS.weight_size;
        elseif area > 1500
            burnScore = burnScore + PARAMS.weight_size;
        end
        
        % CLASSIFICATION based on user selection
        % Scale bounding box back to original image size
        bb_original = props(k).BoundingBox * scaleFactor;
        
        if detectBurns && burnScore > holeScore && burnScore >= PARAMS.min_confidence
            burnBoxes = [burnBoxes; bb_original];
        elseif detectHoles && holeScore > burnScore && holeScore >= PARAMS.min_confidence
            holeBoxes = [holeBoxes; bb_original];
        elseif detectBurns && detectHoles
            % If both are selected and scores are close, classify to the higher one
            if burnScore >= PARAMS.min_confidence && burnScore >= holeScore
                burnBoxes = [burnBoxes; bb_original];
            elseif holeScore >= PARAMS.min_confidence && holeScore > burnScore
                holeBoxes = [holeBoxes; bb_original];
            end
        end
    end
    
    numBurns = size(burnBoxes, 1);
    numHoles = size(holeBoxes, 1);
end
