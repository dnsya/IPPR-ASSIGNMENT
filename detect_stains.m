function defects = detect_stains(img)
    defects = [];
    counter = 1;
    
    gray_image = rgb2gray(img);
    filtered_image = medfilt2(gray_image, [3,3]);
    
    % Invert the image to better spot the stain
    threshold_value = 0.45;
    binary_image = imbinarize(filtered_image, threshold_value);
    inverted_binary_image = ~binary_image;
    inverted_binary_image = imopen(inverted_binary_image, strel('disk',3));
    
    % Fills the holes and keep the largest region of the glove
    filled_image = imfill(inverted_binary_image, 'holes');
    glove_mask = bwareafilt(filled_image, 1);
    glove_mask = imdilate(glove_mask, strel('disk',1));
    
    % find the glove edge and create a 10 pixel buffer zone around it
    glove_edge = bwperim(glove_mask);
    glove_edge_buffer = imdilate(glove_edge, strel('disk', 10));
    glove_interior = glove_mask & ~glove_edge_buffer;
    
    % Find the bright areas and clean up the region
    defect_mask = imopen(inverted_binary_image, strel(ones(5)));
    stain_mask = glove_mask & ~defect_mask;
    stain_mask = imopen(stain_mask, strel('square',2));
    stain_mask = stain_mask & glove_interior;
    
    % Extract the hsv values from the image
    hsv_image = rgb2hsv(img);
    hue = hsv_image(:,:,1);
    sat = hsv_image(:,:,2);
    val = hsv_image(:,:,3);
    
    % detect the bright, colourful regions and calculate the gradient magnitude
    is_bright = val > 0.75;
    is_colorful = sat > 0.2;
    edge_strength = imgradient(gray_image);
    high_edge = edge_strength > 0.05;
    reflection_mask = is_bright & ~is_colorful & ~high_edge;
    stain_mask(reflection_mask) = 0;
    
    % Find the more common stain (red & yellow) that are not that bright
    red_hue = (hue < 0.15) | (hue > 0.85);
    yellow_hue = (hue > 0.08) & (hue < 0.25);
    has_color = sat > 0.25;
    appropriate_brightness = val < 0.6;
    dark_stain_mask = (red_hue | yellow_hue) & has_color & appropriate_brightness;
    dark_stain_mask = dark_stain_mask & glove_interior;
    dark_stain_mask = imopen(dark_stain_mask, strel('disk',1));
    dark_stain_mask = bwareaopen(dark_stain_mask, 15);
    
    % Detect the skin color regions to avoid being identified as stain
    % Same as detect_holes.m btw
    skin_hue = (hue < 0.15) | (hue > 0.85);  % Reddish/yellowish
    skin_sat = sat < 0.35;  % Low saturation
    skin_val = (val > 0.4) & (val < 0.95);  % Not too dark, not too bright
    skin_mask = skin_hue & skin_sat & skin_val;
    skin_mask = bwareaopen(skin_mask, 200);
    
    % Remove skin regions from both stain masks
    stain_mask = stain_mask & ~skin_mask;
    dark_stain_mask = dark_stain_mask & ~skin_mask;
    
    % Combine bright and dark stains
    combined_stain_mask = stain_mask | dark_stain_mask;
    
    % Find the connected components and calculate the eccentricity (elongation)
    stain_cc = bwconncomp(combined_stain_mask);
    stain_props = regionprops(stain_cc, 'BoundingBox','Area','Eccentricity');
        
    for k = 1:stain_cc.NumObjects
        area = stain_props(k).Area;
        ecc = stain_props(k).Eccentricity;
        bbox = stain_props(k).BoundingBox;
            
        if area > 400 && area < 20000 && ecc < 0.8
            d.type = ['Stain ' int2str(counter)];
            d.bbox = bbox;
            defects = [defects; d];
            counter = counter + 1;
        end
    end
end