function glove_defect_detection_gui
% GLOVE_DEFECT_DETECTION_GUI  Main GUI for the Glove Defect Detection System.
%
% Features:
%   - Import glove images from disk
%   - Detect multiple defect types: tears, contamination, and stains
%   - Visualise detection results with annotated bounding boxes
%   - Display a formatted detection summary with quality status

    clc;
    close all;

    %% ---------------------------------------------------------------
    %  Create main figure window
    %% ---------------------------------------------------------------
    fig = figure('Name',        'Glove Defect Detection System', ...
                 'NumberTitle', 'off',                           ...
                 'Position',    [100 100 1200 650],              ...
                 'Resize',      'off',                           ...
                 'MenuBar',     'none',                          ...
                 'Color',       [0.1 0.1 0.1]);

    

    %% ---------------------------------------------------------------
    %  Image display axes
    %% ---------------------------------------------------------------
    axOriginal = axes('Parent',   fig,          ...
                      'Units',    'pixels',     ...
                      'Position', [30 250 400 350], ...
                      'Box',      'on');
    title(axOriginal, 'Original Image',         ...
          'FontSize', 12, 'FontWeight', 'bold', 'Color', 'white');
    axis off;

    axResult = axes('Parent',   fig,            ...
                    'Units',    'pixels',       ...
                    'Position', [470 250 400 350], ...
                    'Box',      'on');
    title(axResult, 'Detection Result',         ...
          'FontSize', 12, 'FontWeight', 'bold', 'Color', 'white');
    axis off;

    %% ---------------------------------------------------------------
    %  Control panel
    %% ---------------------------------------------------------------
    uipanel('Parent',          fig,                   ...
            'Units',           'pixels',              ...
            'Position',        [910 250 260 350],     ...
            'Title',           'Controls',            ...
            'FontSize',        11,                    ...
            'FontWeight',      'bold',                ...
            'BackgroundColor', [0.15 0.15 0.15],      ...
            'ForegroundColor', 'white');

    % Return button
    uicontrol('Style',           'pushbutton',                          ...
              'String',          'RETURN',                              ...
              'Position',        [957 605 170 40],                      ...
              'FontSize',        12,                                    ...
              'FontWeight',      'bold',                                ...
              'BackgroundColor', [1 0 0],                               ...
              'ForegroundColor', 'black',                               ...
              'Callback',        @(src,event) main_glove_selection_gui);

    % Import Image
    uicontrol('Style',           'pushbutton',   ...
              'String',          'Import Image', ...
              'Position',        [930 530 220 50], ...
              'FontSize',        12,              ...
              'FontWeight',      'bold',          ...
              'BackgroundColor', [0.3 0.6 0.9],  ...
              'ForegroundColor', 'white',         ...
              'Callback',        @loadImage);

    % Detect All Defects
    uicontrol('Style',           'pushbutton',        ...
              'String',          'Detect All Defects', ...
              'Position',        [930 460 220 50],    ...
              'FontSize',        12,                  ...
              'FontWeight',      'bold',              ...
              'BackgroundColor', [0.2 0.7 0.3],       ...
              'ForegroundColor', 'white',              ...
              'Callback',        @detectAllDefects);

    % Detect Tears
    uicontrol('Style',           'pushbutton',    ...
              'String',          'Detect Tears',  ...
              'Position',        [930 400 220 40], ...
              'FontSize',        11,              ...
              'BackgroundColor', [0.9 0.5 0.5],   ...
              'ForegroundColor', 'white',          ...
              'Callback',        @detectTearsOnly);

    % Detect Contamination
    uicontrol('Style',           'pushbutton',           ...
              'String',          'Detect Contamination', ...
              'Position',        [930 350 220 40],       ...
              'FontSize',        11,                     ...
              'BackgroundColor', [0.5 0.5 0.9],          ...
              'ForegroundColor', 'white',                 ...
              'Callback',        @detectContaminationOnly);

    % Detect Stains
    uicontrol('Style',           'pushbutton',    ...
              'String',          'Detect Stains', ...
              'Position',        [930 300 220 40], ...
              'FontSize',        11,              ...
              'BackgroundColor', [0.9 0.7 0.2],   ...
              'ForegroundColor', 'white',          ...
              'Callback',        @detectStainOnly);

    % Clear
    uicontrol('Style',           'pushbutton', ...
              'String',          'Clear',      ...
              'Position',        [930 270 220 25], ...
              'FontSize',        10,           ...
              'BackgroundColor', [0.95 0.95 0.95], ...
              'ForegroundColor', 'black',      ...
              'Callback',        @clearDisplay);

    %% ---------------------------------------------------------------
    %  Results panel and scrollable text box
    %% ---------------------------------------------------------------
    resultPanel = uipanel('Parent',          fig,                   ...
                          'Units',           'pixels',              ...
                          'Position',        [30 30 1140 200],      ...
                          'Title',           'Detection Results',   ...
                          'FontSize',        11,                    ...
                          'FontWeight',      'bold',                ...
                          'BackgroundColor', [0.15 0.15 0.15],      ...
                          'ForegroundColor', 'white');

    txtResults = uicontrol('Parent',          resultPanel,          ...
                           'Style',           'listbox',            ...
                           'Position',        [10 10 1110 170],     ...
                           'FontSize',        10,                   ...
                           'FontName',        'FixedWidth',         ...
                           'BackgroundColor', [0.15 0.15 0.15],     ...
                           'ForegroundColor', 'white',              ...
                           'Max',             2,                    ...
                           'Min',             0,                    ...
                           'String', {
                               '╔═══════════════════════════════════════════════════════════╗';
                               '║          GLOVE DEFECT DETECTION SYSTEM                    ║';
                               '╚═══════════════════════════════════════════════════════════╝';
                               '';
                               '  Welcome to the Glove Defect Detection System';
                               '';
                               '  Please load an image to begin analysis.';
                               '';
                               '  Detectable Defects:';
                               '    • Tears ';
                               '    • Surface Contamination ';
                               '    • Stains ';
                               '';
                               '═══════════════════════════════════════════════════════════';
                           });

    %% ---------------------------------------------------------------
    %  Initialise shared handles structure
    %% ---------------------------------------------------------------
    handles.image     = [];
    handles.gloveMask = [];
    handles.fileName  = '';
    handles.axOriginal = axOriginal;
    handles.axResult   = axResult;
    guidata(fig, handles);

    % ================================================================
    %  CALLBACK FUNCTIONS
    % ================================================================

    % ----------------------------------------------------------------
    function loadImage(~, ~)
        handles = guidata(fig);

        [fileName, pathName] = uigetfile( ...
            {'*.jpg;*.jpeg;*.png;*.bmp', 'Image Files (*.jpg, *.jpeg, *.png, *.bmp)'; ...
             '*.*', 'All Files (*.*)'}, ...
            'Select a glove image');

        if isequal(fileName, 0)
            return;   % User cancelled dialog
        end

        handles.image    = imread(fullfile(pathName, fileName));
        handles.fileName = fileName;
        guidata(fig, handles);

        % Show original image
        axes(axOriginal);
        imshow(handles.image);
        title(axOriginal, ['Original: ' fileName], ...
              'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none', 'Color', 'white');

        % Clear result pane
        axes(axResult);
        cla;
        title(axResult, 'Detection Result', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'white');
        axis off;

        set(txtResults, 'String', {
            '╔═══════════════════════════════════════════════════════════╗';
            '║              IMAGE LOADED SUCCESSFULLY                    ║';
            '╚═══════════════════════════════════════════════════════════╝';
            '';
            '  Ready for defect detection analysis.';
            '';
            '  Click "Detect All Defects" to analyse all defect types,';
            '  or select an individual button for a specific defect.';
            '';
            '═══════════════════════════════════════════════════════════';
        });
    end

    % ----------------------------------------------------------------
    function detectAllDefects(~, ~)
        handles = guidata(fig);

        if isempty(handles.image)
            errordlg('Please load an image first.', 'No Image');
            return;
        end

        set(txtResults, 'String', {
            '╔═══════════════════════════════════════════════════════════╗';
            '║              PROCESSING... PLEASE WAIT                    ║';
            '╚═══════════════════════════════════════════════════════════╝';
            '';
            '  Analysing image for defects...';
            '';
            '  Step 1: Segmenting glove region';
            '  Step 2: Detecting contamination';
            '  Step 3: Detecting tears';
            '  Step 4: Detecting stains';
            '';
            '═══════════════════════════════════════════════════════════';
        });
        drawnow;

        I = handles.image;

        % --- Segmentation ---
        gloveMask        = segment_glove_hsv(I);
        handles.gloveMask = gloveMask;
        guidata(fig, handles);

        % --- Defect detection ---
        [contamMask, contamStats, numContam] = detect_contamination(I, gloveMask);
        handles.contamMask = contamMask;
        guidata(fig, handles);

        [~, tearStats, numTears]   = detect_tears(I, gloveMask);
        [stainMask, stainStats, numStains] = detect_stains(I, gloveMask);
        handles.stainMask = stainMask;
        guidata(fig, handles);

        % --- Draw annotations on result axes ---
        axes(axResult);
        imshow(I);
        hold on;

        % Tears — blue bounding box
        for i = 1:length(tearStats)
            rectangle('Position', tearStats(i).BoundingBox, ...
                      'EdgeColor', 'blue', 'LineWidth', 1);
            plot(tearStats(i).Centroid(1), tearStats(i).Centroid(2), ...
                 'b+','MarkerSize', 12, 'LineWidth', 1);
            text(tearStats(i).BoundingBox(1), tearStats(i).BoundingBox(2) - 10, ...
                 'TEAR', 'Color', 'blue', 'FontSize', 9, 'FontWeight', 'bold');
        end

        % Contamination — red dashed bounding box
        for i = 1:length(contamStats)
            rectangle('Position', contamStats(i).BoundingBox, ...
                      'EdgeColor', [1 0 0], 'LineWidth', 1);
            text(contamStats(i).BoundingBox(1), contamStats(i).BoundingBox(2) - 10, ...
                 'CONTAMINATION', 'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');
        end

        % Stains — yellow bounding box
        for i = 1:length(stainStats)
            rectangle('Position', stainStats(i).BoundingBox, ...
                      'EdgeColor', [1 0.8 0], 'LineWidth', 1);
            plot(stainStats(i).Centroid(1), stainStats(i).Centroid(2), ...
                 'y+', 'MarkerSize', 12, 'LineWidth', 1);
            text(stainStats(i).BoundingBox(1), stainStats(i).BoundingBox(2) - 10, ...
                 'STAIN', 'Color', [0.9 0.7 0], 'FontSize', 9, 'FontWeight', 'bold');
        end

        hold off;
        title(axResult, 'All Defects Detected', 'FontSize', 12, 'FontWeight', 'bold', 'Color', 'white');

        % --- Summary results panel ---
        totalDefects = numTears + numContam + numStains;

        set(txtResults, 'String', {
            '╔═══════════════════════════════════════════════════════════╗';
            '║              DEFECT DETECTION SUMMARY                     ║';
            '╚═══════════════════════════════════════════════════════════╝';
            '';
            sprintf('  Total Defects Found: %d', totalDefects);
            '';
            '─────────────────────────────────────────────────────────────';
            '  DEFECT BREAKDOWN:';
            '─────────────────────────────────────────────────────────────';
            '';
            sprintf('    [TEARS]           : %d detected', numTears);
            sprintf('    [CONTAMINATION]   : %d detected', numContam);
            sprintf('    [STAINS]          : %d detected', numStains);
            '';
            '─────────────────────────────────────────────────────────────';
            sprintf('  QUALITY STATUS: %s', getQualityStatus(totalDefects));
            '─────────────────────────────────────────────────────────────';
            '';
            '  VISUAL LEGEND:';
            '    • Red Box/Marker    → Tears';
            '    • Red Box           → Contamination';
            '    • Yellow Box/Marker → Stains';
            '';
            '═══════════════════════════════════════════════════════════';
        });
    end

    % ----------------------------------------------------------------
    function detectTearsOnly(~, ~)
        handles = guidata(fig);

        if isempty(handles.image)
            errordlg('Please load an image first.', 'No Image');
            return;
        end

        I         = handles.image;
        gloveMask = segment_glove_hsv(I);

        [~, tearStats, numTears] = detect_tears(I, gloveMask);

        displaySingleDefect(I, tearStats, 'TEAR', 'b', 'Tears Detected');

        set(txtResults, 'String', {
            '╔═══════════════════════════════════════════════════════════╗';
            '║                  TEAR DETECTION RESULTS                   ║';
            '╚═══════════════════════════════════════════════════════════╝';
            '';
            sprintf('  Total Tears Detected: %d', numTears);
            '';
            '  Detection Area   : Glove body ';
            '  Detection Method : Skin-colour topology detection';
            '';
            '═══════════════════════════════════════════════════════════';
        });
    end

    % ----------------------------------------------------------------
    function detectStainOnly(~, ~)
        handles = guidata(fig);

        if isempty(handles.image)
            errordlg('Please load an image first.', 'No Image');
            return;
        end

        I         = handles.image;
        gloveMask = segment_glove_hsv(I);

        [~, stainStats, numStains] = detect_stains(I, gloveMask);

        displaySingleDefect(I, stainStats, 'STAIN', [1 0.8 0], 'Stains Detected');

        set(txtResults, 'String', {
            '╔═══════════════════════════════════════════════════════════╗';
            '║                 STAIN DETECTION RESULTS                   ║';
            '╚═══════════════════════════════════════════════════════════╝';
            '';
            sprintf('  Total Stains Detected: %d', numStains);
            '';
            '  Detection Type   : Surface discoloration and marks';
            '  Detection Method : Statistical deviation analysis';
            '';
            '═══════════════════════════════════════════════════════════';
        });
    end

    % ----------------------------------------------------------------
    function detectContaminationOnly(~, ~)
        handles = guidata(fig);

        if isempty(handles.image)
            errordlg('Please load an image first.', 'No Image');
            return;
        end

        I         = handles.image;
        gloveMask = segment_glove_hsv(I);

        [contamMask, contamStats, numContam] = detect_contamination(I, gloveMask);
        handles.contamMask = contamMask;
        guidata(fig, handles);

        % Draw contamination results
        axes(axResult);
        imshow(I);
        hold on;
        for i = 1:length(contamStats)
            rectangle('Position', contamStats(i).BoundingBox, ...
                      'EdgeColor', [1 0 0], 'LineWidth', 1, 'LineStyle', '--');
            text(contamStats(i).BoundingBox(1), ...
                 contamStats(i).BoundingBox(2) - 12, ...
                 'CONTAMINATION', ...
                 'Color', 'r', 'FontSize', 10, 'FontWeight', 'bold');
        end
        hold off;
        title(axResult, 'Contamination Detected', 'FontSize', 12, 'FontWeight', 'bold');

        set(txtResults, 'String', {
            '╔═══════════════════════════════════════════════════════════╗';
            '║            CONTAMINATION DETECTION RESULTS                ║';
            '╚═══════════════════════════════════════════════════════════╝';
            '';
            sprintf('  Total Contamination Regions: %d', numContam);
            '';
            '  Detection Type   : Foreign objects on glove surface';
            '  Examples         : Rubber bands, strings, dirt, residue';
            '';
            '═══════════════════════════════════════════════════════════';
        });
    end

    % ================================================================
    %  HELPER FUNCTIONS
    % ================================================================

    % ----------------------------------------------------------------
    function displaySingleDefect(I, stats, label, color, titleStr)
    % Draws centroid markers and labels for a single defect type
    % on the result axes.
        handles = guidata(fig);
        axes(handles.axResult);
        imshow(I);
        hold on;
        for i = 1:length(stats)
            plot(stats(i).Centroid(1), stats(i).Centroid(2), ...
                 '+', 'Color', color, 'MarkerSize', 14, 'LineWidth', 1);
            text(stats(i).Centroid(1) + 20, stats(i).Centroid(2) - 20, ...
                 label, 'Color', color, 'FontSize', 9, 'FontWeight', 'bold', ...
                 'Margin', 2);
        end
        hold off;
        title(handles.axResult, titleStr, ...
              'FontSize', 12, 'FontWeight', 'bold', 'Color', 'white');
    end

    % ----------------------------------------------------------------
    function clearDisplay(~, ~)
    % Resets both axes and the results panel to their initial state.
        axes(axOriginal);
        cla;
        title(axOriginal, 'Original Image', ...
              'FontSize', 12, 'FontWeight', 'bold', 'Color', 'white');
        axis off;

        axes(axResult);
        cla;
        title(axResult, 'Detection Result', ...
              'FontSize', 12, 'FontWeight', 'bold', 'Color', 'white');
        axis off;

        set(txtResults, 'String', {
            '╔═══════════════════════════════════════════════════════════╗';
            '║          GLOVE DEFECT DETECTION SYSTEM                    ║';
            '╚═══════════════════════════════════════════════════════════╝';
            '';
            '  Display cleared. Ready for next analysis.';
            '';
            '  Please load an image to begin detection.';
            '';
            '═══════════════════════════════════════════════════════════';
        });

        handles           = guidata(fig);
        handles.image     = [];
        handles.gloveMask = [];
        handles.fileName  = '';
        guidata(fig, handles);
    end

    % ----------------------------------------------------------------
    function status = getQualityStatus(totalDefects)
    % Returns a quality verdict string based on the total defect count.
        if totalDefects == 0
            status = 'PASS    — No defects detected';
        elseif totalDefects <= 2
            status = 'WARNING — Minor defects detected';
        else
            status = 'FAIL    — Multiple defects detected';
        end
    end

end