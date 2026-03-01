function [burnBoxes, stainBoxes, numBurns, numStains] = detect_BurnsAndStains(img, detectBurns, detectStains)

    % Thresholds
    BURN_S_MAX  = 0.65;  BURN_V_MAX   = 0.60;  % Burns: dark + desaturated
    STAIN_S_MIN = 0.20;  STAIN_V_MIN  = 0.25;  % Stains: visible saturation, not dark
    STAIN_HDEV  = 0.12;  % Stains: hue deviation from glove base color
    BURN_SOL_MAX = 0.85; BURN_ECC_MIN = 0.75;  % Burns: irregular / elongated
    STAIN_SOL_MIN = 0.70; STAIN_CIRC_MIN = 0.45; % Stains: solid blob
    BURN_TEX_MIN = 20;   STAIN_EDGE_MAX = 0.20; % Texture
    W_COLOR = 4; W_SHAPE = 3; W_TEX = 2; W_SIZE = 1; MIN_CONF = 3;

    % Preprocessing 
    [filledMask, scaleFactor, img, grayImg] = glovePreprocess(img);

    hsvImg = rgb2hsv(img);
    H = hsvImg(:,:,1); S = hsvImg(:,:,2); V = hsvImg(:,:,3);

    % Estimate glove base hue (neutral, non-dark glove pixels only)
    gloveH  = H(filledMask & V > 0.3 & S < 0.5);
    baseHue = ternary(numel(gloveH) > 100, median(gloveH), 0.1);

    % Burn candidate mask (dark regions)
    grayImg(~filledMask) = 255;
    candidateMask = imadjust(imcomplement(grayImg), [0.55 0.8], [0 1]) > 0.5;
    candidateMask = imopen(candidateMask, strel('disk', 3));
    candidateMask = imclose(candidateMask, strel('disk', 7));
    candidateMask = imfill(candidateMask, 'holes');
    candidateMask = bwareaopen(candidateMask, 200);
    candidateMask(bwdist(~candidateMask) * 2 < 8) = 0;  % remove shadows
    candidateMask = bwareaopen(candidateMask, 350);

    % Stain candidate mask (colorful, hue-deviated regions)
    hueDist = min(abs(H - baseHue), 1 - abs(H - baseHue));
    stainCandidateMask = filledMask & S > STAIN_S_MIN & V > STAIN_V_MIN & hueDist > STAIN_HDEV;
    stainCandidateMask = imopen(stainCandidateMask, strel('disk', 3));
    stainCandidateMask = imclose(stainCandidateMask, strel('disk', 5));
    stainCandidateMask = imfill(stainCandidateMask, 'holes');
    stainCandidateMask = bwareaopen(stainCandidateMask, 200);

    %Region properties on merged mask
    grayNorm = uint8(255 * mat2gray(grayImg));
    props = regionprops(candidateMask | stainCandidateMask, ...
        'BoundingBox', 'PixelIdxList', 'Area', 'Solidity', 'Eccentricity', 'Circularity');

    burnBoxes = []; stainBoxes = [];

    for k = 1:length(props)
        bb = props(k).BoundingBox;
        if max(bb(3), bb(4)) / min(bb(3), bb(4)) > 3.5, continue; end

        idx        = props(k).PixelIdxList;
        meanS      = mean(S(idx));  meanV = mean(V(idx));
        meanHueDev = min(abs(mean(H(idx)) - baseHue), 1 - abs(mean(H(idx)) - baseHue));

        tbb = clipBB(bb, size(img));
        regionGray      = grayNorm(tbb(2):tbb(2)+tbb(4)-1, tbb(1):tbb(1)+tbb(3)-1);
        textureVariance = std(double(regionGray(:)));
        edgeDensity     = sum(sum(edge(regionGray, 'Canny'))) / numel(regionGray);

        burnScore  = W_COLOR * (meanS < BURN_S_MAX && meanV < BURN_V_MAX) ...
                   + W_SHAPE * (props(k).Solidity < BURN_SOL_MAX || props(k).Eccentricity > BURN_ECC_MIN) ...
                   + W_TEX   * (textureVariance > BURN_TEX_MIN) ...
                   + W_SIZE  * (props(k).Area > 1500);

        stainScore = W_COLOR * (meanS > STAIN_S_MIN && meanHueDev > STAIN_HDEV && meanV > STAIN_V_MIN) ...
                   + (meanS > 0.5) ...
                   + W_SHAPE * (props(k).Solidity > STAIN_SOL_MIN && props(k).Circularity > STAIN_CIRC_MIN) ...
                   + W_TEX   * (edgeDensity < STAIN_EDGE_MAX) ...
                   + W_SIZE  * (props(k).Area < 500);


        bb_original = bb * scaleFactor;
        if detectBurns  && burnScore  >= MIN_CONF && burnScore  >= stainScore, burnBoxes  = [burnBoxes;  bb_original]; end
        if detectStains && stainScore >= MIN_CONF && stainScore >  burnScore,  stainBoxes = [stainBoxes; bb_original]; end
    end

    numBurns  = size(burnBoxes, 1);
    numStains = size(stainBoxes, 1);
end

function bb = clipBB(bb, imgSize)
    bb = round([max(1,bb(1)-5) max(1,bb(2)-5) bb(3)+10 bb(4)+10]);
    bb(3) = min(bb(3), imgSize(2)-bb(1)+1);
    bb(4) = min(bb(4), imgSize(1)-bb(2)+1);
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end