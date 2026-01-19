function defects = detect_stains(img)
    defects = [];
    counter = 1;
    
    % STEP 1: Preprocessing
    gray_image = rgb2gray(img);
    filtered_image = medfilt2(gray_image, [3,3]);
    
    % STEP 2: Thresholding
    threshold_value = 0.45;
    binary_image = imbinarize(filtered_image, threshold_value);
    inverted_binary_image = ~binary_image;
    inverted_binary_image = imopen(inverted_binary_image, strel('disk',3));
    
    % STEP 3: Extract glove mask and interior region
    filled_image = imfill(inverted_binary_image, 'holes');
    glove_mask = bwareafilt(filled_image, 1);
    glove_mask = imdilate(glove_mask, strel('disk',1));
    
    % Edge buffer to avoid folds/shadows
    glove_edge = bwperim(glove_mask);
    buffer_radius = 10;
    glove_edge_buffer = imdilate(glove_edge, strel('disk', buffer_radius));
    glove_interior = glove_mask & ~glove_edge_buffer;
    
    % STEP 4: Initial bright stain mask
    defect_mask = imopen(inverted_binary_image, strel(ones(5)));
    stain_mask = glove_mask & ~defect_mask;
    stain_mask = imopen(stain_mask, strel('square',2));
    stain_mask = stain_mask & glove_interior;
    
    % STEP 5: Remove reflections (specular highlights)
    hsv_image = rgb2hsv(img);
    hue = hsv_image(:,:,1);
    sat = hsv_image(:,:,2);
    val = hsv_image(:,:,3);
    
    % Candidate bright regions
    is_bright = val > 0.75;
    is_colorful = sat > 0.2;
    edge_strength = imgradient(gray_image);
    high_edge = edge_strength > 0.05;
    reflection_mask = is_bright & ~is_colorful & ~high_edge;
    stain_mask(reflection_mask) = 0;
    
    % STEP 6: Detect dark stains
    red_hue = (hue < 0.15) | (hue > 0.85);
    yellow_hue = (hue > 0.08) & (hue < 0.25);
    has_color = sat > 0.25;
    appropriate_brightness = val < 0.6;
    dark_stain_mask = (red_hue | yellow_hue) & has_color & appropriate_brightness;
    dark_stain_mask = dark_stain_mask & glove_interior;
    dark_stain_mask = imopen(dark_stain_mask, strel('disk',1));
    dark_stain_mask = bwareaopen(dark_stain_mask, 15);
    
    % STEP 6.5: EXCLUDE SKIN-COLORED REGIONS (likely holes showing skin)
    % Detect skin-colored regions using same logic as detect_holes
    skin_hue = (hue < 0.15) | (hue > 0.85);  % Reddish/yellowish
    skin_sat = sat < 0.35;  % Low saturation
    skin_val = (val > 0.4) & (val < 0.95);  % Not too dark, not too bright
    skin_mask = skin_hue & skin_sat & skin_val;
    skin_mask = bwareaopen(skin_mask, 200);
    
    % Remove skin regions from both stain masks
    stain_mask = stain_mask & ~skin_mask;
    dark_stain_mask = dark_stain_mask & ~skin_mask;
    
    % STEP 7: Combine bright and dark stains
    combined_stain_mask = stain_mask | dark_stain_mask;
    
    % STEP 8: Connected components and filtering
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