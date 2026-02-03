classdef RubberGloveDDSystem < matlab.apps.AppBase
    % Glove Defect Detection App (Optimized & Fully Fixed)

    %% Properties
    properties (Access = public)
        UIFigure
        ImagePanel
        ImageAxes
        GalleryPanel
        GalleryScrollPanel
        DefectPanel
        DefectType1CheckBox
        DefectType2CheckBox
        DefectType3CheckBox
        ControlPanel
        ImportButton
        AnalyzeButton
        ClearButton
        PreviousButton
        NextButton
        ResetButton
        ImageCounterLabel
        ConsolePanel
        ConsoleTextArea
        TitlePanel
        TitleLabel
    end

    properties (Access = private)
        ImageFiles = {}        % Cell array of image file paths
        CurrentImageIndex = 0
        CurrentImage = []
        GalleryButtons = {}    % Gallery thumbnail panels
        BGColor = [0.15, 0.15, 0.15]; % dark
        SCColor = [0.95, 0.85, 0.10];
    end

    %% Private Methods
    methods (Access = private)

        function btn = createButton(~, parent, text, pos, bgColor, callback)
            btn = uibutton(parent, 'push');
            btn.Text = text;
            btn.Position = pos;
            btn.FontWeight = 'bold';
            btn.BackgroundColor = bgColor;
            
            % FIX: If background is bright (Cyan/Yellow), use Black text. 
            % Otherwise, use White text.
            if sum(bgColor) > 1.5
                btn.FontColor = [0 0 0]; % Black
            else
                btn.FontColor = [1 1 1]; % White
            end
            
            btn.ButtonPushedFcn = callback;
        end

        function cb = createCheckBox(~, parent, text, pos, defaultValue)
            cb = uicheckbox(parent);
            cb.Text = text;
            cb.Position = pos;
            cb.Value = defaultValue;
        end

        function showImage(app, img)
            cla(app.ImageAxes);
            imshow(img, 'Parent', app.ImageAxes);
            axis(app.ImageAxes, 'image');
        end

        function drawDefect(app, bb, label, color)
            expand = 10;
            bb_expanded = [bb(1)-expand, bb(2)-expand, bb(3)+2*expand, bb(4)+2*expand];
            rectangle(app.ImageAxes, 'Position', bb_expanded, 'EdgeColor', color, 'LineWidth', 3);
            text(app.ImageAxes, bb(1), bb(2)-15, label, 'Color', color, ...
                'FontWeight', 'bold', 'FontSize', 12, 'BackgroundColor', 'w');
        end

        function addConsoleMessage(app, message)
            app.ConsoleTextArea.Value = [app.ConsoleTextArea.Value; message];
            drawnow;
            scroll(app.ConsoleTextArea, 'bottom');
        end

        function val = ternary(app, cond, a, b)
            if cond
                val = a;
            else
                val = b;
            end
        end

        function showPlaceholder(app)
            cla(app.ImageAxes);  % clear everything
            xlim(app.ImageAxes, [0 1]); ylim(app.ImageAxes, [0 1]);
            app.ImageAxes.XTick = []; app.ImageAxes.YTick = [];
            app.ImageAxes.Box = 'on';
            rectangle(app.ImageAxes, 'Position', [0 0 1 1], 'FaceColor', [0 0 0], 'EdgeColor', 'none');
            text(app.ImageAxes, 0.5, 0.5, 'NO IMAGE LOADED', 'Units','normalized', ...
                'HorizontalAlignment','center','VerticalAlignment','middle', ...
                'FontSize',14,'FontWeight','bold','Color',[0.7 0.7 0.7]);
        end

        %% UI Creation
        function createComponents(app)
            % UIFigure
            app.UIFigure = uifigure('Visible','off','Position',[10 10 1320 940], ...
                                    'Name','Glove Defect Detection System', ...
                                    'Color', app.BGColor, 'AutoResizeChildren','off', ...
                                    'Scrollable','off','WindowState','normal');

            % Title Panel
            app.TitlePanel = uipanel(app.UIFigure,'Position',[10 800 1180 50], ...
                                     'BackgroundColor',app.SCColor,'BorderType','line');
            app.TitleLabel = uilabel(app.TitlePanel,'Text','Rubber Glove Defect Detection System', ...
                                     'Position',[0 0 1180 50],'HorizontalAlignment','center', ...
                                     'FontSize',26,'FontWeight','bold','FontColor',[0 0 0]);

            % Image Panel
            app.ImagePanel = uipanel(app.UIFigure,'Title','Image Display & Detection Results', ...
                                     'FontWeight','bold','Position',[10 220 450 570], ...
                                     'BackgroundColor', app.BGColor);
            app.ImageAxes = uiaxes(app.ImagePanel,'Position',[10 10 430 530], ...
                                   'XTick',[],'YTick',[],'Box','on','DataAspectRatio',[1 1 1]);
            app.showPlaceholder();

            % Gallery Panel
            app.GalleryPanel = uipanel(app.UIFigure,'Title','Image Gallery','FontWeight','bold', ...
                                       'Position',[470 430 720 360],'Scrollable','on','BackgroundColor', app.BGColor);
            app.GalleryScrollPanel = uipanel(app.GalleryPanel,'Position',[10 10 700 320], ...
                                             'Scrollable','on','BorderType','none','BackgroundColor', app.BGColor);

            % Defect Panel
            app.DefectPanel = uipanel(app.UIFigure,'Title','Defect Selection','FontWeight','bold', ...
                                      'Position',[470 220 240 200],'BackgroundColor', app.BGColor);
            app.DefectType1CheckBox = createCheckBox(app, app.DefectPanel, 'Sticky/Fused Fingers',[20 130 150 22],1);
            app.DefectType2CheckBox = createCheckBox(app, app.DefectPanel, 'Burn Marks',[20 90 150 22],1);
            app.DefectType3CheckBox = createCheckBox(app, app.DefectPanel, 'Holes',[20 50 150 22],1);

            % Control Panel
            app.ControlPanel = uipanel(app.UIFigure,'Title','Controls','FontWeight','bold', ...
                                       'Position',[720 220 470 200],'BackgroundColor', app.BGColor);
            app.ImportButton = createButton(app, app.ControlPanel,'Import Images',[15 110 150 45],[0.00, 0.75, 0.90], @(btn,event) app.ImportButtonPushed());
            app.AnalyzeButton = createButton(app, app.ControlPanel,'Analyze',[180 110 130 45],[0.70, 0.95, 0.00], @(btn,event) app.AnalyzeButtonPushed());
            app.ClearButton   = createButton(app, app.ControlPanel,'Clear',[325 110 130 45],[0.95, 0.20, 0.30], @(btn,event) app.ClearButtonPushed());
            app.PreviousButton = createButton(app, app.ControlPanel,'<< Previous',[15 50 150 45],app.SCColor, @(btn,event) app.PreviousButtonPushed());
            app.NextButton = createButton(app, app.ControlPanel,'Next >>',[180 50 130 45],app.SCColor, @(btn,event) app.NextButtonPushed());
            app.ResetButton = createButton(app, app.ControlPanel,'Reset',[325 50 130 45],app.BGColor, @(btn,event) app.ResetButtonPushed());
            app.ImageCounterLabel = uilabel(app.ControlPanel,'Text','No images loaded','Position',[15 10 200 22]);

            % Console Panel
            app.ConsolePanel = uipanel(app.UIFigure,'Title','Console Output','FontWeight','bold', ...
                                       'Position',[10 10 1180 200],'BackgroundColor', app.BGColor);
            app.ConsoleTextArea = uitextarea(app.ConsolePanel,'Position',[10 10 1160 165], ...
                                             'BackgroundColor', app.BGColor,'FontColor',app.SCColor, ...
                                             'FontName','Courier New','Editable','off','Value',{'>> System initialized. Ready...'});

            % --- Finally update buttons AFTER all components exist ---
            app.updateButtonStates();

            % Show figure
            app.UIFigure.Visible = 'on';
            movegui(app.UIFigure,'center');
            app.UIFigure.Resize = 'off';
        end

        %% Image Gallery Functions
        function createGallery(app)
            % Clear existing gallery
            delete(app.GalleryScrollPanel.Children);
            app.GalleryButtons = {};
            
            % Pre-calculate constants
            numImages = length(app.ImageFiles);
            if numImages == 0, return; end
            
            thumbnailsPerRow = 5;
            spacing = 15;
            itemWidth = 120;
            itemHeight = 120;
            thumbWidth = 110;
            thumbHeight = 80;
            
            totalRows = ceil(numImages / thumbnailsPerRow);
            scrollHeight = max(320, totalRows * (itemHeight + spacing));
            app.GalleryScrollPanel.Position(4) = scrollHeight;
            
            % Create all thumbnails
            for i = 1:numImages
                % Calculate position (pre-computed)
                row = floor((i-1) / thumbnailsPerRow);
                col = mod(i-1, thumbnailsPerRow);
                xPos = col * (itemWidth + spacing) + spacing;
                yPos = scrollHeight - (row + 1) * (itemHeight + spacing);
                
                % Create container panel (clickable)
                itemPanel = uipanel(app.GalleryScrollPanel, ...
                    'Position', [xPos yPos itemWidth 110], ...
                    'BorderType', 'none', ...
                    'BackgroundColor', app.BGColor, ...
                    'ButtonDownFcn', @(~,~) app.galleryButtonCallback(i));
                
                % Create axes for image (minimal properties)
                ax = uiaxes(itemPanel, ...
                    'Position', [5 25 thumbWidth thumbHeight], ...
                    'XTick', [], 'YTick', [], ...
                    'XColor', 'none', 'YColor', 'none', ...
                    'Box', 'off');
                ax.Toolbar.Visible = 'off';
                ax.Interactions = [];
                
                % Load and display image
                img = imread(app.ImageFiles{i});
                imgHandle = imshow(img, 'Parent', ax);
                axis(ax, 'image');
                imgHandle.ButtonDownFcn = @(~,~) app.galleryButtonCallback(i);
                
                % Add filename label
                [~, name, ext] = fileparts(app.ImageFiles{i});
                uilabel(itemPanel, ...
                    'Text', [name ext], ...
                    'Position', [5 0 thumbWidth 20], ...
                    'HorizontalAlignment', 'center', ...
                    'FontSize', 8);
                
                app.GalleryButtons{i} = itemPanel;
            end
        end

        function galleryButtonCallback(app,index)
            app.CurrentImageIndex = index;
            app.displayImage(index);
            app.updateImageCounter();
            app.updateButtonStates();
        end

        %% Display & Detection
        function displayImage(app,index)
            if index<1 || index>length(app.ImageFiles), return; end
            try
                app.CurrentImage = imread(app.ImageFiles{index});
                app.showImage(app.CurrentImage);
                [~,name,ext] = fileparts(app.ImageFiles{index});
                app.addConsoleMessage(sprintf('> Displaying: %s%s',name,ext));
                app.updateGalleryHighlight();
            catch ME
                app.addConsoleMessage(sprintf('> ERROR: %s',ME.message));
            end
        end

        function updateGalleryHighlight(app)
            for i = 1:length(app.GalleryButtons)
                panel = app.GalleryButtons{i};
                if isvalid(panel)
                    if i==app.CurrentImageIndex
                        panel.BorderType = 'line';
                        panel.BorderWidth = 1;
                        panel.HighlightColor = app.SCColor;
                        scroll(app.GalleryPanel, panel);
                    else
                        panel.BorderType = 'none';
                    end
                end
            end
        end

        function updateImageCounter(app)
            if isempty(app.ImageFiles)
                app.ImageCounterLabel.Text = 'No images loaded';
            else
                app.ImageCounterLabel.Text = sprintf('Image %d of %d', app.CurrentImageIndex, length(app.ImageFiles));
            end
        end

        %% Defect Detection
        function detectDefects(app,detectSticky,detectBurns,detectHoles)
            img = app.CurrentImage;
            allBoxes={}; allLabels={}; allColors={}; totalDefects=0;

            if detectSticky
                app.addConsoleMessage('> Detecting sticky/fused fingers...');
                [fusedBoxes,numFused] = detect_StickyFingers(img);
                for i=1:size(fusedBoxes,1)
                    allBoxes{end+1}=fusedBoxes(i,:); allLabels{end+1}='FUSED'; allColors{end+1}='c';
                end
                totalDefects = totalDefects + numFused;
                app.addConsoleMessage(app.ternary(numFused>0, ...
                    sprintf('> Found %d fused finger region(s)',numFused),'> No fused fingers detected'));
            end

            if detectBurns || detectHoles
                app.addConsoleMessage('> Detecting burn marks and holes...');
                [burnBoxes,holeBoxes,numBurns,numHoles] = detect_BurnsAndHoles(img,detectBurns,detectHoles);

                if detectBurns
                    if numBurns>0, for i=1:size(burnBoxes,1), allBoxes{end+1}=burnBoxes(i,:); allLabels{end+1}='BURN'; allColors{end+1}='r'; end; end
                    totalDefects = totalDefects + numBurns;
                    app.addConsoleMessage(app.ternary(numBurns>0,sprintf('> Found %d burn mark(s)',numBurns),'> No burn marks detected'));
                end

                if detectHoles
                    if numHoles>0, for i=1:size(holeBoxes,1), allBoxes{end+1}=holeBoxes(i,:); allLabels{end+1}='HOLE'; allColors{end+1}='b'; end; end
                    totalDefects = totalDefects + numHoles;
                    app.addConsoleMessage(app.ternary(numHoles>0,sprintf('> Found %d hole(s)',numHoles),'> No holes detected'));
                end
            end

            % Display
            app.showImage(img); hold(app.ImageAxes,'on');
            for i=1:length(allBoxes), app.drawDefect(allBoxes{i},allLabels{i},allColors{i}); end
            hold(app.ImageAxes,'off');

            app.addConsoleMessage(app.ternary(totalDefects>0, ...
                sprintf('> ANALYSIS COMPLETE: %d total defect(s) - REJECT',totalDefects), ...
                '> ANALYSIS COMPLETE: No defects - PASS'));
        end

        %% Button Callbacks
        function ImportButtonPushed(app)
            [files,path] = uigetfile({'*.jpg;*.png;*.bmp','Image Files'},'Select Images','MultiSelect','on');
            if isequal(files,0), return; end
            if ~iscell(files), files={files}; end
            app.ImageFiles = fullfile(path,files);
            app.CurrentImageIndex = 1;
            app.createGallery();
            app.displayImage(1);
            app.updateImageCounter();
            app.updateButtonStates();
        end

        function AnalyzeButtonPushed(app)
            if isempty(app.CurrentImage), app.addConsoleMessage('> ERROR: No image loaded.'); return; end
            if ~app.DefectType1CheckBox.Value && ~app.DefectType2CheckBox.Value && ~app.DefectType3CheckBox.Value
                app.addConsoleMessage('> Select a defect type first.'); return;
            end
            app.addConsoleMessage('> Starting analysis...');
            app.detectDefects(app.DefectType1CheckBox.Value, app.DefectType2CheckBox.Value, app.DefectType3CheckBox.Value);
        end

        function ClearButtonPushed(app)
            if app.CurrentImageIndex>0
                app.displayImage(app.CurrentImageIndex);
                app.addConsoleMessage('> Detection cleared.');
            end
        end

        function PreviousButtonPushed(app)
            if app.CurrentImageIndex>1
                app.CurrentImageIndex = app.CurrentImageIndex - 1;
                app.displayImage(app.CurrentImageIndex);
                app.updateImageCounter();
            end
            app.updateButtonStates();
        end

        function NextButtonPushed(app)
            if app.CurrentImageIndex<length(app.ImageFiles)
                app.CurrentImageIndex = app.CurrentImageIndex + 1;
                app.displayImage(app.CurrentImageIndex);
                app.updateImageCounter();
            end
            app.updateButtonStates();
        end

        function ResetButtonPushed(app)
            app.ImageFiles = {}; app.CurrentImageIndex = 0; app.CurrentImage = []; app.GalleryButtons = {};
            app.showPlaceholder();
            if isvalid(app.GalleryScrollPanel)
                delete(app.GalleryScrollPanel.Children); app.GalleryScrollPanel.Position(4)=320;
            end
            app.ImageCounterLabel.Text='No images loaded';
            app.ConsoleTextArea.Value={'> System reset. Ready...'};
            app.updateButtonStates();
        end

        function updateButtonStates(app)
            hasImages = ~isempty(app.ImageFiles);
            app.ImportButton.Enable   = 'on';
            app.AnalyzeButton.Enable  = app.ternary(hasImages,'on','off');
            app.ClearButton.Enable    = app.ternary(hasImages,'on','off');
            app.ResetButton.Enable    = app.ternary(hasImages,'on','off');
            app.PreviousButton.Enable = app.ternary(hasImages && app.CurrentImageIndex>1,'on','off');
            app.NextButton.Enable     = app.ternary(hasImages && app.CurrentImageIndex<length(app.ImageFiles),'on','off');
        end
    end

    %% App Creation / Deletion
    methods (Access = public)
        function app = RubberGloveDDSystem
            app.createComponents();
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end
end