function defects = detect_holes(img)
    defects = [];

    counter = 1;
    hsv = rgb2hsv(img);
    gray = rgb2gray(img);
    
    % Detect pale skin (adjust thresholds based on your skin tone)
    skin_hue = (hsv(:,:,1) < 0.15) | (hsv(:,:,1) > 0.85);  % Reddish/yellowish
    skin_sat = hsv(:,:,2) < 0.35;  % Low saturation
    skin_val = (hsv(:,:,3) > 0.4) & (hsv(:,:,3) < 0.95);  % Not too dark, not too bright
    
    skin_mask = skin_hue & skin_sat & skin_val;
    skin_mask = bwareaopen(skin_mask, 200);
    
    % Method 2: Brightness difference
    % Black glove is very dark, skin is much brighter
    bright_regions = gray > 0.4;
    
    % Combine both methods
    potential_holes = skin_mask & bright_regions;
    
    % Clean up
    potential_holes = imclose(potential_holes, strel('disk', 3));
    potential_holes = bwareaopen(potential_holes, 300);
    
    % Get glove outline to ensure holes are within glove
    bw = ~imbinarize(gray, 0.325);
    bw = bwareaopen(bw, 500);
    glove_filled = imfill(bw, 'holes');
    glove_region = bwareaopen(glove_filled, 5000);
    
    % Keep only holes within glove region
    holes_final = potential_holes & glove_region;
    
    stats = regionprops(holes_final, 'BoundingBox', 'Area', 'Solidity', 'Perimeter');
    
    for k = 1:numel(stats)
        area = stats(k).Area;
        solidity = stats(k).Solidity;
        circularity = 4 * pi * area / (stats(k).Perimeter^2);
        
        % Filter criteria
        if area > 400 && area < 40000 && solidity > 0.4 && circularity > 0.2
            d.type = ['Hole ' int2str(counter)];
            d.bbox = stats(k).BoundingBox;
            defects = [defects; d];
            counter = counter + 1;
        end
    end
end