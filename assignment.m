function assignment() 
    loaded_images = {};      
    image_filenames = {};    
    current_index = 1;

    % Colors
    colors.bg_black = [0.15 0.15 0.15];
    colors.bg_blue = [0.3 0.5 0.8];
    colors.bg_grey = [0.2 0.2 0.2];
    colors.bg_light = [0.25 0.25 0.25];

    colors.text_light = [0.9 0.9 0.9];

    colors.accent_blue = [0.3 0.5 0.8];
    colors.accent_yellow = [0.8 0.7 0.3];
    colors.accent_green = [0.3 0.7 0.4];
    colors.accent_red = [0.8 0.3 0.3];
    colors.accent_purple = [0.6 0.3 0.7];


    % Figures
    main_figure = uifigure('Name', 'IPPR', ...
                        'Position', [50, 100, 1100, 700], ...
                        'Color', colors.bg_black);

    main_title = uilabel(main_figure, ...
        "Text", "IPPR Assignment - Nitrile Glove", ...
        'Position', [20 645 1060 40], ...
        'FontSize', 18, ...
        'FontWeight', "Bold", ...
        'HorizontalAlignment', 'Center', ...
        'FontColor', colors.text_light, ...
        'BackgroundColor', colors.bg_blue);


    % Left Column
    left_column = uipanel(main_figure, ...
        "Title", "Image", ...
        "FontSize", 11, ...
        'Position', [20 30 475 600], ...
        'BackgroundColor', colors.bg_grey);

    image_ax = uiaxes(left_column, ...
        'Position', [0 0 475 580]);
    image_ax.XTick = [];
    image_ax.YTick = [];
    title(image_ax, 'Load images to start', ...
        'FontSize', 11);


    % Right Column
    right_column = uipanel(main_figure, ...
        "Title", "Controls", ...
        "FontSize", 11, ...
        'Position', [505 30 575 600], ...
        'BackgroundColor', colors.bg_grey);


        % Button Panel
    button_panel = uipanel(right_column, ...
        'Title', 'Buttons', ...
        'Position', [5 505 565 70], ...
        'BackgroundColor', colors.bg_light, ...
        'ForegroundColor', colors.accent_blue, ...
        'HighlightColor', colors.accent_blue, ...
        'FontSize', 10);

    button_upload = uibutton(button_panel, 'push', ...
        'Text', 'Upload Image', ...
        'Position', [10 10 100 35], ...
        'FontSize', 10, ...
        'BackgroundColor', colors.accent_blue, ...
        'FontColor', colors.text_light, ...
        'ButtonPushedFcn', @load_images);

    button_process = uibutton(button_panel, 'push', ...
        'Text', 'Process Image', ...
        'Position', [120 10 100 35], ...
        'FontSize', 10, ...
        'BackgroundColor', colors.accent_green, ...
        'FontColor', colors.text_light, ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(src, evt) process_image());

    button_previous = uibutton(button_panel, 'push', ...
        'Text', 'Previous Image', ...
        'Position', [230 10 100 35], ...
        'FontSize', 10, ...
        'BackgroundColor', colors.accent_yellow, ...
        'FontColor', colors.text_light, ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(src, evt) previous_image());

    button_next = uibutton(button_panel, 'push', ...
        'Text', 'Next Image', ...
        'Position', [340 10 100 35], ...
        'FontSize', 10, ...
        'BackgroundColor', colors.accent_yellow, ...
        'FontColor', colors.text_light, ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(src, evt) next_image());

    button_clear = uibutton(button_panel, 'push', ...
        'Text', 'Clear Images', ...
        'Position', [450 10 100 35], ...
        'FontSize', 10, ...
        'BackgroundColor', colors.accent_red, ...
        'FontColor', colors.text_light, ...
        'Enable', 'off', ...
        'ButtonPushedFcn', @(src, evt) clear_images());


        % Gallery Panel
    gallery_panel = uipanel(right_column, ...
        'Title', 'Gallery', ...
        'Position', [5 200 565 300], ...
        'BackgroundColor', colors.bg_light, ...
        'ForegroundColor', colors.accent_yellow, ...
        'HighlightColor', colors.accent_yellow, ...
        'FontSize', 10);

    thumbnail_panel = uipanel(gallery_panel, ...
        'Position', [5 5 555 272.5], ...
        'Scrollable', 'on', ...
        'BackgroundColor', colors.bg_black);


        % Dialog Panel
    console_panel = uipanel(right_column, ...
        'Title', 'Console', ...
        'Position', [5 5 565 190], ...
        'BackgroundColor', colors.bg_light, ...
        'ForegroundColor', colors.accent_purple, ...
        'HighlightColor', colors.accent_purple, ...
        'FontSize', 10);

    console_ui = uitextarea(console_panel, ...
        'Position', [5 5 555 162.5], ...
        'Value', {'Upload Images to start!'}, ...
        'FontSize', 11, ...
        'FontColor', colors.text_light, ...
        'Editable', 'off', ...
        'BackgroundColor', colors.bg_black);


    % Callback Functions 
    function load_images(~, ~) 
        add_log('Uploading Files...');
        
        % Extract the file name and file path from the selected file
        [filenames, filepath] = uigetfile({ ...
            '*.jpg;*.jpeg;*.png;*.bmp', 'Image Files'; ...
            '*.*', 'All Files'...
            }, "Select Files", ...
            "MultiSelect", "on");   % Enable multiselect to upload multiple files

        if isequal(filenames, 0)
            add_log('Upload Cancelled');
            return;
        end
        
        if ~iscell(filenames)
            filenames = {filenames};    % Convert the single element into a cell array
            add_log('One file detected');
        else
            add_log(['Multiple files detected: ' num2str(length(filenames))]);
        end
        
        % Clear the containers!
        loaded_images = {};      
        image_filenames = {};    
        current_index = 1;

        for i = 1:length(filenames)
            try
                fullpath = fullfile(filepath, filenames{i});

                img = imread(fullpath);
                loaded_images{i} = img; % Add all the images into the variable
                image_filenames{i} = filenames{i};  % All all the names into the variable
    
                add_log(['Loaded: ' filenames{i}]);
            catch ME
                add_log(['Error loading ' filenames{i} ': ' ME.message]);
            end
        end

        if ~isempty(loaded_images)
            display_images();
            disable_button();
            gallery_images();

            add_log(['Loaded ' num2str(length(loaded_images)) ' images']);
        end
    end

    function display_images()
        if isempty(loaded_images)
            return;
        end

        img = loaded_images{current_index}; % Load the current image index
        filename = image_filenames{current_index};

        imshow(img, 'Parent', image_ax);
        title(image_ax, ['Image ' num2str(current_index) ': ' filename]);
    end

    % Gallery Functions
    function gallery_images()
        % Clear all the thumbnails first
        delete(thumbnail_panel.Children);
        
        if isempty(loaded_images)
            return;
        end
    
        active_image = length(loaded_images);   % Find the number of images
        cols = min(4, active_image);
        rows = ceil(active_image / cols);

        thumb_width = 120;
        thumb_height = 190;
        thumb_margin = 15;

        for i = 1:active_image
            col = mod(i-1, cols);
            row = floor((i-1) / cols);
            flipped_row = rows - 1 - row;
    
            x = thumb_width * col + ((thumb_margin * col) / 2) + thumb_margin;
            y = thumb_height * flipped_row;
    
            % If there is only 1 row, ensure the picture is in the top of the gallery
            if rows == 1
                y = thumbnail_panel.Position(4) - thumb_height - thumb_margin;
            end

            % Set the images to the gallery
            thumb_ax = uiaxes(thumbnail_panel, ...
                'Position', [x y thumb_width thumb_height]);
            thumb_ax.XTick = [];
            thumb_ax.YTick = [];
    
            thumbnail = imresize(loaded_images{i}, [180 120]);
            imshow(thumbnail, 'Parent', thumb_ax);
            title(thumb_ax, ['#' num2str(i) ' ' image_filenames{i}]);
    
            % Create set img to the images in the gallery, to be clickable
            img = findobj(thumb_ax, 'Type', 'image');
            img.ButtonDownFcn = @(src,event) click_image(i);
        end
    end    

    function click_image(index)
        current_index = index;
        display_images();
        disable_button();
        add_log(['Viewing Image: #' num2str(current_index)]);
    end

    % Navigation Functions
    function next_image(~, ~)
        if current_index < length(loaded_images)
            % Increase the index and dispaly it
            current_index = current_index + 1;
            display_images();

            % By moving to the next image, then the previous image is now available to be chosen.
            button_previous.Enable = "on";  

            add_log(['Next Image: #' num2str(current_index)]);
        else
            button_next.Enable = "off"; % If there is no next image, disable the button

            add_log(sprintf( ...
                'Cannot go to next image. Current image: %d / %d.', ...
                current_index, length(loaded_images)));
        end
    end

    function previous_image(~, ~)
        if current_index > 1
            % Reduce the index and display the image
            current_index = current_index - 1;
            display_images();

            % By moving to the previous image, then the next image is now available to be chosen.
            button_next.Enable = "on";

            add_log(['Previous Image: #' num2str(current_index)]);
        else
            button_previous.Enable = "off"; % If there is no image previously, turn off the button

            add_log(sprintf( ...
                'Cannot go to previous image. Current image: %d / %d.', ...
                current_index, length(loaded_images)));
        end
    end

    function disable_button()
        % If there is no image, turn off the buttons
        active_image = length(loaded_images);

        if active_image == 0
            button_process.Enable = "off";
            button_clear.Enable = "off";
            button_next.Enable = "off";
            button_previous.Enable = "off";
        else
            button_process.Enable = "on";
            button_clear.Enable = "on";
            button_next.Enable = "on";
            button_previous.Enable = "on";
        end
    end

    function clear_images(~, ~)
        % Clear the variables
        loaded_images = {};      
        image_filenames = {};    
        current_index = 1;

        % Clear the image, gallery, and disable the button
        cla(image_ax);
        disable_button();
        delete(thumbnail_panel.Children);
        
        title(image_ax, 'Load images to start');

        add_log('Images cleared');
    end

    function add_log(message) 
        current_log = console_ui.Value;
        timestamp = char(datetime('now', 'Format', 'HH:mm:ss'));
        new_entry = ['[' timestamp '] ' message];

        % Concatenate the current (old) and new log
        console_ui.Value = [current_log; new_entry];
    end

    % Process Functions
    function process_image()
        add_log(['Processing Image #' num2str(current_index) ' ' image_filenames{current_index} '...']);

        img = loaded_images{current_index};
        
        defects = [];
        
        % Check the defects and if there is any, concatenate them to the array
        defects = [defects; detect_holes(img)];
        defects = [defects; detect_stains(img)];
        defects = [defects; detect_missing_finger(img)];

        % Draw and report the defect
        draw_defect(defects);
        report_defects(defects);
        add_log('Processing Complete');
    end
    
    function draw_defect (defects)
        % Clear the previous defect shape
        cla(image_ax);
        imshow(loaded_images{current_index}, 'Parent', image_ax);
        hold(image_ax, 'on');
            
        for i = 1:length(defects)
            bbox = defects(i).bbox;
            % Add a red rectangle on the bounding box location
            rectangle(image_ax, ...
                'Position', bbox, ...
                'EdgeColor', colors.accent_red, ...
                'LineWidth', 1);
            
            text(image_ax, bbox(1), bbox(2) - 20, defects(i).type, ...
                'Color', colors.accent_red, 'FontSize', 12, 'FontWeight', 'bold');
        end

        hold(image_ax, 'off');
    end

    function report_defects(defects)
        if isempty(defects)
            add_log('No defects detected');
            return;
        end

        add_log(['Defects detected: ' num2str(numel(defects))]);

        % Report the defects X, Y axis and width, height.
        for i = 1:numel(defects)
            bbox = defects(i).bbox;
            msg = sprintf('- %s at [X: %.1f, Y: %.1f, W: %.1f, H: %.1f]', ...
                          defects(i).type, bbox(1), bbox(2), bbox(3), bbox(4));
    
            add_log(msg);
        end
    end
end