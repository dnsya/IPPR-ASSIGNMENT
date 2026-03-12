function [tearMask, tearStats, numTears] = detect_tears(I, gloveMask)
% DETECT_TEARS Detects tear defects in latex gloves based on skin color
%
% Input:
%   I - RGB image of the glove
%   gloveMask - Binary mask of the glove region
%
% Output:
%   tearMask  - Binary mask of detected tears (holes exposing skin)
%   tearStats - region properties of detected tears
%   numTears  - number of tears detected

% Convert to double
Iproc = im2double(I);

% --- Step 1: Detect skin-color pixels inside glove ---
% Use normalized RGB for skin detection
R = Iproc(:,:,1);
G = Iproc(:,:,2);
B = Iproc(:,:,3);

% Normalize RGB to reduce illumination effects
sumRGB = R + G + B + eps;
rNorm = R ./ sumRGB;
gNorm = G ./ sumRGB;

% Simple skin-color rule for pale/light skin
skinMask = (rNorm > 0.34 & rNorm < 0.6) & ...   % more red than blue/green
           (gNorm > 0.25 & gNorm < 0.45) & ...
           (R > 0.6 & G > 0.5 & B > 0.45);       % overall brightness for pale skin

% Restrict to glove area
skinMask = skinMask & gloveMask;

% Morphological cleanup
skinMask = imopen(skinMask, strel('disk',3));
skinMask = imclose(skinMask, strel('disk',5));
skinMask = bwareaopen(skinMask, 50); % remove tiny noise

% --- Step 2: Topology-based filtering ---
CC = bwconncomp(skinMask);
Igray = rgb2gray(I);

stats = regionprops(CC, Igray, 'Area', 'Centroid', 'BoundingBox', 'Eccentricity','MeanIntensity');

validTears = false(1,length(stats));
for i = 1:length(stats)
    % Filter based on area and brightness
    areaOK = stats(i).Area > 55 && stats(i).Area < 5000;
    brightnessOK = stats(i).MeanIntensity > 0.35;
    validTears(i) = areaOK && brightnessOK;
end

% --- Step 3: Final outputs ---
tearMask = ismember(labelmatrix(CC), find(validTears));
tearStats = stats(validTears);
numTears = nnz(validTears);

fprintf('Number of tears detected: %d\n', numTears);

% Optional visualization
if numTears > 0
    figure('Name','Tear Detection (Skin-Color)','NumberTitle','off');
    imshow(I); hold on;
    for i = 1:length(stats)
        if validTears(i)
            rectangle('Position', stats(i).BoundingBox, 'EdgeColor','r','LineWidth',2);
            plot(stats(i).Centroid(1), stats(i).Centroid(2), 'r+', 'MarkerSize',15,'LineWidth',2);
            text(stats(i).Centroid(1)+10, stats(i).Centroid(2), sprintf('T%d',i), 'Color','r','FontWeight','bold');
        end
    end
    hold off;
end
