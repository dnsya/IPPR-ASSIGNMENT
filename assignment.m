function assignment_test() 
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
    main_figure = uifigure('Name', 'Assignment Test', ...
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
    dialog_panel = uipanel(right_column, ...
        'Title', 'Dialog', ...
        'Position', [5 5 565 190], ...
        'BackgroundColor', colors.bg_light, ...
        'ForegroundColor', colors.accent_purple, ...
        'HighlightColor', colors.accent_purple, ...
        'FontSize', 10);

    dialog_ui = uitextarea(dialog_panel, ...
        'Position', [5 5 555 162.5], ...
        'Value', {'Upload Images to start!'}, ...
        'FontSize', 11, ...
        'FontColor', colors.text_light, ...
        'Editable', 'off', ...
        'BackgroundColor', colors.bg_black);


    % Callback Functions 
    function load_images(~, ~) 
        add_dialog('Uploading Files...');
        
        [filenames, filepath] = uigetfile({ ...
            '*.jpg;*.jpeg;*.png;*.bmp', 'Image Files'; ...
            '*.*', 'All Files'...
            }, "Select Files", ...
            "MultiSelect", "on");

        if isequal(filenames, 0)
            add_dialog('Upload Cancelled');
            return;
        end
        
        if ~iscell(filenames)
            filenames = {filenames};
            add_dialog('One file detected');
        else
            add_dialog(['Multiple files detected: ' num2str(length(filenames))]);
        end
        
        % Clear the containers!
        loaded_images = {};      
        image_filenames = {};    
        current_index = 1;

        for i = 1:length(filenames)
            try
                fullpath = fullfile(filepath, filenames{i});

                img = imread(fullpath);
                loaded_images{i} = img;
                image_filenames{i} = filenames{i};
    
                add_dialog(['Loaded: ' filenames{i}]);
            catch ME
                add_dialog(['Error loading ' filenames{i} ': ' ME.message]);
            end
        end

        if ~isempty(loaded_images)
            display_images();
            disable_button();
            gallery_images();

            add_dialog(['Loaded ' num2str(length(loaded_images)) ' images']);
        end
    end

    function display_images()
        if isempty(loaded_images)
            return;
        end

        img = loaded_images{current_index};
        filename = image_filenames{current_index};

        imshow(img, 'Parent', image_ax);
        title(image_ax, ['Image ' num2str(current_index) ': ' filename]);
    end

    % Gallery Functions
    function gallery_images()
        delete(thumbnail_panel.Children);
        
        if isempty(loaded_images)
            return;
        end
    
        active_image = length(loaded_images);
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
    
            if rows == 1
                y = thumbnail_panel.Position(4) - thumb_height - thumb_margin;
            end

            thumb_ax = uiaxes(thumbnail_panel, ...
                'Position', [x y thumb_width thumb_height]);
            thumb_ax.XTick = [];
            thumb_ax.YTick = [];
    
            thumbnail = imresize(loaded_images{i}, [180 120]);
            imshow(thumbnail, 'Parent', thumb_ax);
            title(thumb_ax, ['#' num2str(i) ' ' image_filenames{i}]);
    
            img = findobj(thumb_ax, 'Type', 'image');
            img.ButtonDownFcn = @(src,event) click_image(i);
        end
    end    

    function click_image(index)
        current_index = index;
        display_images();
        disable_button();
        add_dialog(['Viewing Image: #' num2str(current_index)]);
    end

    % Navigation Functions
    function next_image(~, ~)
        if current_index < length(loaded_images)
            current_index = current_index + 1;
            display_images();
            button_previous.Enable = "on";

            add_dialog(['Next Image: #' num2str(current_index)]);
        else
            button_next.Enable = "off";

            add_dialog(sprintf( ...
                'Cannot go to next image. Current image: %d / %d.', ...
                current_index, length(loaded_images)));
        end
    end

    function previous_image(~, ~)
        if current_index > 1
            current_index = current_index - 1;
            display_images();
            button_next.Enable = "on";

            add_dialog(['Previous Image: #' num2str(current_index)]);
        else
            button_previous.Enable = "off";

            add_dialog(sprintf( ...
                'Cannot go to previous image. Current image: %d / %d.', ...
                current_index, length(loaded_images)));
        end
    end

    function disable_button()
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
        loaded_images = {};      
        image_filenames = {};    
        current_index = 1;
        cla(image_ax);
        disable_button();
        delete(thumbnail_panel.Children);
        
        title(image_ax, 'Load images to start');

        add_dialog('Images cleared');
    end

    function add_dialog(message) 
        current_log = dialog_ui.Value;
        timestamp = char(datetime('now', 'Format', 'HH:mm:ss'));
        new_entry = ['[' timestamp '] ' message];
        dialog_ui.Value = [current_log; new_entry];
    end

    % Process Functions
    function process_image()
        add_dialog(['Processing Image #' num2str(current_index) ' ' image_filenames{current_index} '...']);

        img = loaded_images{current_index};
        
        defects = [];
        defects = [defects; detect_holes(img)];
        defects = [defects; detect_stains(img)];
        defects = [defects; detect_missing_finger(img)];

        draw_defect(defects);
        report_defects(defects);
        add_dialog('Processing Complete');
    end
    
    function draw_defect (defects)
        cla(image_ax);
        imshow(loaded_images{current_index}, 'Parent', image_ax);
        hold(image_ax, 'on');
            
        for i = 1:length(defects)
            bbox = defects(i).bbox;
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
            add_dialog('No defects detected');
            return;
        end

        add_dialog(['Defects detected: ' num2str(numel(defects))]);

        for i = 1:numel(defects)
            bbox = defects(i).bbox;
            msg = sprintf('- %s at [X: %.1f, Y: %.1f, W: %.1f, H: %.1f]', ...
                          defects(i).type, bbox(1), bbox(2), bbox(3), bbox(4));
    
            add_dialog(msg);
        end
    end
end