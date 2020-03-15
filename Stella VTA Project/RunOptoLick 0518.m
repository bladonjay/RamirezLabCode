function session=RunOptoLick(settings)
% $Id: RunTreadmill.m 4831 2013-05-13 19:56:09Z nrobinson
% commented by JH Bladon
% RunTreadmill runs a treadmill task with a gui, will open a treadmill
% object, a joystick object (if possible) and will try to connect to the
% plexon map server.
if ~isempty(timerfindall('name','Main RunTreadmill Timer'))
fprintf('you already have the game running \n');
return
end
% reformat the stims so that they are in same output variable as the beams,
% mouse has to withdraw before he gets to be stimmed again
% and do the save thing for excel docs


%% start with some default settings
session.comment = '';       % no default comments yet
session.date = now();       % all annotations


session.box1.lickevents=[0 0 0 0];
session.box1.ratname='mousey 1';

session.box2.lickevents=[0 0 0 0];
session.box2.ratname='mousey 2';

sessionnum=0;
defsettings.irpin='D2'; % this is the pin that turns on all the IR beams
defsettings.box1.Activate=false;
defsettings.box1.LeftPin='D3'; % this is the sensor for the left port in box 1
defsettings.box1.RightPin='D4'; % this is the sensor for the right port in box 1
defsettings.box1.LaserPin='D5'; % this is the pin that plugs into the laser in box 1
defsettings.box1.PokeTime=.01; % seconds
defsettings.box1.CoolDown=.5; % seconds
defsettings.box1.Withdraw=1;

defsettings.box2.LeftPin='D7';
defsettings.box2.RightPin='D8';
defsettings.box2.LaserPin='D6';
defsettings.box2.PokeTime=.01; % seconds
defsettings.box2.CoolDown=.5; % seconds
defsettings.box2.Activate=false;
defsettings.box2.Withdraw=1;
boxnames={'box1','box2'};

if(nargin == 0)
    settings = checksettings();
else
    settings = checksettings(settings);
end

%% start all our hard parameters
% set time stream
rstream = RandStream('mt19937ar','Seed', mod(prod(clock()),2^32));
% set the global time stream
RandStream.setGlobalStream(rstream);

% just in case we work with plexon
% plex server number
plexserver = 0;

% Initiate poke sensor

a=arduino;
% turn the ir beams on  (indicator light on arduino)
writeDigitalPin(a,defsettings.irpin,1);


% make sure
autocloselaserserial = onCleanup(@() clear('a'));


% set up our time recorder, that will use a 0.2 second update rate
tim = timer('StartFcn',@startfcn,'TimerFcn',@timerfcn,...
    'StopFcn',@stopfcn,'ErrorFcn',@errorfcn,'Period',0.2,...
    'ExecutionMode','fixedDelay','Name','Main RunTreadmill Timer');



% do you need to save on shutdown?
% this goes true once the animal has done something (e.g. has poked)
needtosave = false;

% start a history seed
history = [];

% create a time reference point
timeref = tic;

%% session annotations
Pokenum=0; % start at 0 pokes


%% open the gui
h = TaskGUI();
set(h.controls,'CloseRequestFcn',@closeButton)
set(h.timer,'CloseRequestFcn',@toggleTimer);
set(h.open,'Callback',@openHist);
set(h.save,'Callback',@saveHist);
set(h.pause,'Callback',@playpause);
set(h.reset,'Callback',@resetchecker);
set(h.showtimer,'Callback',@toggleTimer);

set(h.TestLaser1,'Callback',@TestLaser1);
set(h.TestLaser2,'Callback',@TestLaser2);

set(h.Activate1,'Callback',@Activate1);
set(h.Activate2,'Callback',@Activate2);

set(h.settings,'Callback',@settingscallback);


applysettings;


%% timer functions

% start stops screensaver and switches the start stop button
    function startfcn(varargin)
        output(h.maindsp, 'Disabling Screen Saver...');
        [status, result] = dos('FlipSS /off');
        if(status == 0), output(h.maindsp, 'Screen Saver Disabled.');
        else, output(h.maindsp, regexprep(result,'\n',' '));
        end
        
        
        set(h.pause,'String','Pause');
        set(h.pause,'Enable','on');
        
        if ~any([settings.box1.Activate settings.box2.Activate])
            output(h.maindsp,'No boxes enabled, stopping');
            stop(tim);
        end
        for i=1:2
            if settings.(boxnames{i}).Activate
                set(h.(['TestLaser' num2str(i)]),'Enable','off');
            end
        end
        
        
    end

    function errorfcn(varargin)
        output(h.maindsp, 'Error encountered.');
    end

% stop function adds screen saver, and switches stop button
    function stopfcn(varargin)
        output(h.maindsp, sprintf('Pausing...'));
        
        
        output(h.maindsp, 'Enabling Screen Saver...');
        [status, result] = dos('FlipSS /on');
        if(status == 0); output(h.maindsp, 'Screen Saver Enabled.');
        else output(h.maindsp, regexprep(result,'\n',' '));
        end
        
        set(h.pause,'String','Start');
        set(h.pause,'Enable','on');
        set(h.TestLaser1,'Enable','on');
        set(h.TestLaser2,'Enable','on');
    end



% timer function will execute every 0.01 seconds once you press the
% start button on the GUI
    function timerfcn(varargin)
        
        
        
        % here we process each input
        % should probably have two fx, one to get events, one to
        % process events
        
        
        getEvents;
        
        process_event;
        
        % if were using plexon, see if plexons sending an event
        
        % and update timestamps
        updateTimers();
        updateCounter();
        updateDisplay();

    end


%% this is the process evetn fx, e.g. the output response fx
    function getEvents
        % this gathers the inputs
        % will record an input history here, e.g. ongoing record of poking,
        % will probably ts each tick and record broken or not.
        % these are organized by left first then right, and each cell is a
        % box
        
        % e.g. session.lickevents{1}(1,:)= left box 1 beam status and ts of
        % checker
        
        % for each box, if its active, add to the session, and needtosave
        % looks like: leftstat,rightstat, 0, ts
        for i=1:2
            if settings.(boxnames{i}).Activate
                % tack on to the matrix
                session.(boxnames{i}).lickevents=[session.(boxnames{i}).lickevents;...
                    readDigitalPin(a,settings.(boxnames{i}).LeftPin) ...
                    readDigitalPin(a,settings.(boxnames{i}).RightPin) 0 toc(timeref)];
                
                needtosave=1;
            end
        end
        
    end

% this processes the outputs, only responds given the event history
    function process_event
        % if either cell has anything in it, and its running, see what we
        % should do
        % for each box
        for i=1:2
            % get the lickevents
            tmpsession=session.(boxnames{i});
            tmpsettings=settings.(boxnames{i});
            lickevents=tmpsession.lickevents;
            
            % if there are more than one tries, and if the box is activated
            if size(lickevents,1)>2 && settings.(boxnames{i}).Activate
                % if he just started a poke, alert terminal
                % lickevents looks like beam1 beam2 laser ts
                % he has to have unpoked since last stim, and it has to have
                % been a while ago
                if ~lickevents(end,1)
                    if lickevents(end-1,1)
                        % add to number of pokes
                        output(h.maindsp, sprintf('Rat in box %d initiated new poke',i));
                    end
                    
                    % find last stim, if not, pretend it was start of day
                    laststim=find(lickevents(:,3)==1,1,'last');
                    if isempty(laststim), laststim=1; end
                    
                    % find out if he withdrew
                    if settings.(boxnames{i}).Withdraw
                        didwithdraw=any(find(lickevents(laststim:end,1)==1));
                    else
                        didwithdraw=1;
                    end
                    
                    % if he withdrew and lick ts is greater than cooldown time
                    if  lickevents(end,end)>lickevents(laststim,4)+tmpsettings.CoolDown && didwithdraw
                        
                        % find all the samples in the past second (the delay)
                        breakidx = lickevents(:,4)>lickevents(end,4)-tmpsettings.PokeTime;
                        recentbreaks=lickevents(breakidx,1);
                        % now if those all are broken... hit him
                        if ~any(recentbreaks)
                            % add a laser pulse to the log
                            session.(boxnames{i}).lickevents(end,3) = 1;
                            % pulse it
                            writeDigitalPin(a,tmpsettings.LaserPin,1);
                            writeDigitalPin(a,tmpsettings.LaserPin,0);
                            % and write to ledger
                            output(h.maindsp, sprintf('pulsing laser in box %d, ts (%.2f)', i, toc(timeref)));
                            
                        end
                    end
                end
            end
        end
    end


%% for modifying settings (opens new window)
    function settingscallback(varargin) %#ok<VANUS>
        settings = changesettings(settings, h);
        settings = checksettings(settings);
        applysettings;
    end

    function applysettings()
        % apply the settings, specifically all the pins
        configurePin(a,settings.box1.LeftPin,'Pullup');
        configurePin(a,settings.box1.RightPin,'Pullup');
        configurePin(a,settings.box2.LeftPin,'Pullup');
        configurePin(a,settings.box2.RightPin,'Pullup');
        
        updateDisplay();
        updateCounter();
    end

    function settings = checksettings(settings)
        if(nargin==0); settings = defsettings;
        else
            % Now check all the rest of the settings, making sure they are
            % at least present and the correct variable type.
            settings = checkfieldtypes(settings, defsettings);
        end
        
        
    end

% check fieldtypes makes sure that new struct doesnt have missing
% or messed up fields (it only turns bad fields into old struct
% fields, othewise it takes the new structs fields
    function newstruct = checkfieldtypes(newstruct, refstruct)
        fields = fieldnames(refstruct);
        
        for j = 1:size(fields,1)
            % if new struct doesnt have the field, or its class is
            % wrong, new struct takes old structs field
            if(~isfield(newstruct,fields{j}) || ...
                    ~isa(newstruct.(fields{j}),class(refstruct.(fields{j}))))
                newstruct.(fields{j}) = refstruct.(fields{j});
                
                % if newstruct has a field but its empty, or it has a nan,
                % use old struct var
            elseif(isnumeric(newstruct.(fields{j})) && ...
                    (isempty(newstruct.(fields{j})) || ...
                    any(isnan(newstruct.(fields{j})))))
                newstruct.(fields{j}) = refstruct.(fields{j});
                warning(['Invalid number entered for ' fields{j} ', resetting to default value.'],'Invalid Entry');
            
                % otherwise, keep new struct variable
            elseif(isstruct(newstruct.(fields{j})))
                newstruct.(fields{j}) = checkfieldtypes(newstruct.(fields{j}), refstruct.(fields{j}));
            end
        end
    end
%% saving function
% gotta change these 


    function success = saveHist(varargin) %#ok<VANUS>
        
        if(needtosave)
            % add to comments
            session.comment = char(inputdlg({'Session Comments'},...
                'Session Comments',10,{session.comment}));
            
            % add mouse names
            dlgtitle='Name your mice';
            prompt={'Name Box 1 Mouse','Name Box 2 Mouse'};
            defaultans={session.box1.ratname,session.box2.ratname};
            
            % if yo named your micede
            answer = inputdlg(prompt,dlgtitle,[1 30],defaultans);
            stockans={'oscar','tickle me elmo'};
            if length(answer)>1
            for i=1:2
                if ~isempty(answer{i})
                    session.(['box' num2str(i)]).ratname=answer{i};
                else
                    output(h.maindsp,'You didnt name your animal, he''ll get a funny name');
                    session.(['box' num2str(i)]).ratname=stockans{i};
                end
            end
            elseif length(answer)<1
                for i=1:2, session.(['box' num2str(i)]).ratname=stockans(i); end
            else
                session.box2.ratname=stockans(2);
            end
            
            session.settings = settings;
            savedir=uigetdir(matlabroot,'Choose folder to save your session');
            if isempty(savedir), savedir=matlabroot; end
            randomnumber=num2str(randi(1000,1));
            savename=inputdlg('Name your session','Session Name',[1 30],{['Session-' date ' ' randomnumber]});
            if isempty(savename), savename=['Session-' date]; end
            
            try
                save([savedir '\' savename{1}],'session');
                output(h.maindsp, sprintf('History for %s and %s saved.',...
                    session.box1.ratname,session.box2.ratname));
                needtosave = false;
                
                % try to save as an xl doc.. too much of a pain in the
                % ass...
                 xldata={session.box1.ratname,'','','',session.box2.ratname,'','','';...
                     'Rewarded','nonrewarded','Laser','time','Rewarded','nonrewarded','Laser','time'};
                 
                 animaldata{1}=session.box1.lickevents;
                 animaldata{2}=session.box2.lickevents;
                 
                 % if either is empty, fill it with nans
                 if isempty(animaldata{1}), animaldata{1}=nan(size(animaldata{2})); end
                 if isempty(animaldata{2}), animaldata{2}=nan(size(animaldata{1})); end   
                 
                 % if theyre uneven, fill end of one with nans
                 if diff(cellfun(@(a) size(a,1),animaldata))~=0
                     % whose a bigger mat, take the other
                     [longest, idx]=max([size(animaldata{2},1) size(animaldata{1},1)]);
                     animaldata{idx}(end:longest,1:4)=nan;
                 end
                 
                 % combine, and make an excel 
                 xldata=[xldata;num2cell(animaldata{1}), num2cell(animaldata{2})];

                xlswrite([savedir '\' savename{1} '-exceldata'],xldata);
                success=true;
                
            catch
                success=false;
                output(h.maindsp,'Saving didnt work');
                needtosave=true;
            end
        else, msgbox('Nothing to save.'); success=true;
        end
        updateDisplay();
    end
%% display functions
    function updateDisplay()
        % for each box
        for i=1:2
            settingsstr = sprintf('');

            % if its active write something
            if settings.(['box' num2str(i)]).Activate
                ratname=session.(boxnames{i}).ratname;
                pokestat=session.(boxnames{i}).lickevents;
                % if the rat has poked, how many times did he poke?
                if size(pokestat,1)>=2, pokes=sum(diff(pokestat(:,[1 2]))==-1);
                else, pokes=0; 
                end
                
                if size(pokestat,1)>=2, zaps=sum(pokestat(:,3),1);  
                else, zaps=0; end
                % add these variables to the settings string
                settingsstr=[{[settingsstr ...
                    'Mouse ' ratname]};{[...
                    'pokes=' num2str(pokes) ...
                    ' : stims=' num2str(zaps)]}];
                if(needtosave)
                    set(h.save,'Enable','on');
                else
                    set(h.save,'Enable','off');
                end
            else
                settingsstr=[settingsstr 'Inactive'];
            end
            set(h.(['settings' num2str(i) 'dsp']),'String',settingsstr);
        end
    end

% this is for the maind isplay
    function output(display, str)
        output_list = get(display,'String');
        output_list = output_list(end:-1:1);
        num = length(output_list)+1;
        str = strtrim(str);
        output_list{end+1} = sprintf('%3d  %s',num,str);
        set(display,'String',output_list(end:-1:1));
        drawnow
    end
%%
    % this is just the current time in minutes and seconds from start of
    % session
    function updateTimers()
        ts = toc(timeref);
        if(ishandle(h.timerstr))
            timestr = sprintf('%2.0f:%02.0f',floor(ts/60),mod(floor(ts),60));
            set(h.timerstr,'String',timestr);
        end
    end

    % this is the counter of licks, zaps for each rat
    function updateCounter()
        if(ishandle(h.counter))
            % Automatically loop back to the beginning of the list once
            % you reach the end.
            pokes=[0 0; 0 0]; zaps=[0;0];
            boxstrings={'Inactive','Inactive'};

            for i=1:2
                %output(h.maindsp,'updating counter2');

                if settings.(['box' num2str(i)]).Activate
                    
                    % grab pokes
                    pokestat=session.(boxnames{i}).lickevents;
                   
                    % if more than one row, gather number of pokes
                    if size(pokestat,1)>=2 
                        pokes=sum(diff(pokestat(:,[1 2]))==-1);
                        zaps=sum(pokestat(:,3),1);
                    else, pokes=[0 0]; zaps=0;
                    end
                    %output(h.maindsp,'updating counter3');
                    boxstrings{i}=['Pokes ' num2str(pokes) ' : zaps ' num2str(zaps)];
               
                    if(needtosave), set(h.save,'Enable','on');
                    else, set(h.save,'Enable','off');
                    end
                end
            end
            
            % add these variables to the settings string

            counterstats=[ boxstrings{1} ' \n ' boxstrings{2}];
                
            % Display lap number, object
            set(h.counter,'String',sprintf(counterstats));
        end
    end
%% reset the error checker
    function success = resetchecker(varargin)
        if(islogical(varargin{1}) && varargin{1})
            button = 'Yes';
        else
            button = questdlg('Are you sure you want to reset?','Reset Confirmation...','Yes','No','Yes');
        end
        
        if(strcmp(button,'Yes') && promptSaveSession)
            success = reset();
        else
            output(h.maindsp, 'Save failed or reset cancelled');
            success = false;
        end
    end

    function success = reset()
        needtosave = false;
        
        timeref = tic;
        
        Pokenum = 1;
        sessionnum = 0;
        session.comment = '';
        session.date = now();
        
        
        session.box1.laserpulses=[];
        session.box1.lickevents=[];
        session.box1.ratname='';

        session.box2.laserpulses=[];
        session.box2.lickevents=[];
        session.box2.ratname='';
        
        
        % If arduino is working, good else, fix it
        try
            writeDigitalPin(a,'D13',1);
            writeDigitalPin(a,'D13',0);
        catch
            a=arduino;
        end
        
        set(h.maindsp,'String',{'  1  Session Reset.'});
        
        if(ishandle(h.counter))
            set(h.timerstr,'String','0');
            set(h.counter,'String','0');
            set(h.timerstr,'ForegroundColor','white');
            set(h.counter,'ForegroundColor','white');
        end
        
        updateDisplay();
        updateCounter();
        success = true;
    end
%%
    function success = promptSaveSession()
        if(needtosave)
            button = questdlg('Save unsaved session?','Saving Session...');
            switch button
                case {'Yes'}
                    success = saveHist();
                case {'No'}
                    button2 = questdlg('Are you sure? You will lose your unsaved session.','Clear Session Confirmation...','Yes','No','No');
                    switch button2
                        case {'Yes'}
                            success = true;
                        otherwise
                            success = false;
                    end
                otherwise
                    success = false;
            end
        else
            success = true;
        end
    end
%% top button actions
% if we're pausing, run stop button
    function playpause(varargin) %#ok<VANUS>
        % If currently running, then stop.
        if(strcmp(tim.Running,'on'))
            % actually i think this button switch is redundent
            set(h.pause,'Enable','off');
            stop(tim);
            % If stopped, then start running.
        else
            set(h.pause,'Enable','off');
            start(tim);
        end
    end

    function closeButton(source, varargin) %#ok<VANUS>
        if(strcmp(tim.Running,'off') && promptSaveSession)
            
            delete(source);
            if(ishandle(h.timer))
                delete(h.timer);
            end
            if(isvalid(tim))
                delete(tim);
            end
            
            
            clear a;
            if any(instrfindall)
                fprintf(2,'Manually closing Arduino. \n');
                delete(instrfindall);
            end
        else warndlg('You must click ''Pause'' before closing this window.','Cannot Close');
        end
    end

    function toggleTimer(varargin) %#ok<VANUS>
        switch get(h.timer,'Visible')
            case 'on'
                set(h.timer,'Visible','off');
                set(h.showtimer,'String','Show Timer');
            case 'off'
                set(h.timer,'Visible','on');
                set(h.showtimer,'String','Hide Timer');
                %maximize(h.timer);
        end
    end

%% activate and test button functions

    function Activate1(varargin)
        % if box is active, deactivate and give option to activate again
        if settings.box1.Activate
            set(h.Activate1,'String','Activate 1');
            settings.box1.Activate=false;
        else % if box is inactivated, activate, and set to de
            set(h.Activate1,'String','Dectivate 1');
            settings.box1.Activate=true;
        end
        updateDisplay();
    end

    function Activate2(varargin)
        if settings.box2.Activate
            set(h.Activate2,'String','Activate 2');
            settings.box2.Activate=false;
        else
            set(h.Activate2,'String','Dectivate 2');
            settings.box2.Activate=true;
        end
        updateDisplay();
    end


    function TestLaser1(varargin)
        output(h.maindsp,sprintf('Testing Laser in Box 1'));
        writeDigitalPin(a,settings.box1.LaserPin,1);
        writeDigitalPin(a,settings.box1.LaserPin,0);
    end

    function TestLaser2(varargin)
        output(h.maindsp,sprintf('Testing Laser in Box 2'));
        writeDigitalPin(a,settings.box2.LaserPin,1);
        writeDigitalPin(a,settings.box2.LaserPin,0);
    end
        
%% Organize the windows for the gui thats made at top
    function h = TaskGUI()
        screen = get(0,'ScreenSize');
        winsize = [450 600];
        
        h.controls = figure('Name','Opto-Reward Task',...
            'NumberTitle','off','MenuBar','none',...
            'Position', [10 (screen(4)-winsize(2)-30) winsize]);
        
        h.buttons = uipanel('Parent',h.controls,...
            'Units','normalized','Position',[0.01 0.92 0.98 0.07]);
        
        h.buttons1 = uipanel('Parent',h.controls,...
            'Units','normalized','Position',[0.01 0.76 0.48 0.15]);
        
        h.buttons2 = uipanel('Parent',h.controls,...
            'Units','normalized','Position',[0.51 0.76 0.48 0.15]);
        
        % top six
        h.open = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.02 0.93 0.15 0.05],...
            'String','Open','Enable','off');
        
        h.save = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.18 0.93 0.15 0.05],...
            'String','Save','Enable','off');
        
        h.pause = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.34 0.93 0.15 0.05],...
            'String','Start');
        
        h.reset = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.50 0.93 0.15 0.05],...
            'String','Reset');
        
        h.settings = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.66 0.93 0.15 0.05],...
            'String','Settings');
        
        h.showtimer = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.82 0.93 0.15 0.05],...
            'String','Timer');
        
        % Box 1 Specific buttons
        h.TestLaser1 = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.02 0.85 0.20 0.05],...
            'String','Test Laser 1');
        
        h.Activate1 = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.24 0.85 0.20 0.05],...
            'String','Activate Box 1');
        
        h.settings1dsp = uicontrol(h.controls,'Style','text',...
            'Units','normalized','Position',[0.02 0.77 0.46 0.06],...
            'BackGroundColor',[1 1 1]);
        
        
        % Box 2 Specific buttons
        h.TestLaser2 = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.56 0.85 0.20 0.05],...
            'String','Test Laser 2');
        
        h.Activate2 = uicontrol(h.controls,'Style','pushbutton',...
            'Units','normalized','Position',[0.77 0.85 0.20 0.05],...
            'String','Activate Box 2');
        
        
        h.settings2dsp = uicontrol(h.controls,'Style','text',...
            'Units','normalized','Position',[0.52 0.77 0.46 0.06],...
            'BackGroundColor',[ 1 1 1]);
        
        
        %% general lower panels
        
        
        h.maindsp = uicontrol(h.controls,'Style','edit',...
            'Units','normalized','Position',[0.01 0.01 0.98 0.74],...
            'BackgroundColor','white','HorizontalAlignment','left',...
            'Max',2,'Enable','inactive');
        
        h.timer = figure('Name','Lap Counter',...
            'NumberTitle','off','MenuBar','none','Visible','off',...
            'Position', [5 39 screen(3)-11 screen(4)-63]);
        
        h.counter = uicontrol(h.timer,'Style','text',...
            'Units','normalized','Position',[0 0.5 1 .5],...
            'BackgroundColor','black','ForegroundColor','white',...
            'FontUnits','normalized','FontSize',.25);
        
        h.timerstr = uicontrol(h.timer,'Style','text',...
            'Units','normalized','Position',[0 0 1 .5],...
            'BackgroundColor','black','ForegroundColor','white',...
            'FontUnits','normalized','FontSize',.95);
    end

%% change settings window
    function settings = changesettings(settings, h)
        
        
        
        parentwin = get(h.controls,'Position');
        
        setwin = dialog('Name','Settings',...
            'NumberTitle','off','MenuBar','none');
        
        
        % need left pins, right pins, left poke times, right poke times
        
        % box 1
        % laser pins
        labels.RightPin1 = uicontrol(setwin,'Style','text',...
            'String','Box 1 Right Beam Pin');
        controls.RightPin1 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box1.RightPin);
        
        labels.LeftPin1 = uicontrol(setwin,'Style','text',...
            'String','Box 1 Left Beam Pin');
        controls.LeftPin1 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box1.LeftPin);
        
        labels.LaserPin1 = uicontrol(setwin,'Style','text',...
            'String','Box 1 Laser Pin');
        controls.LaserPin1 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box1.LaserPin);
        
        labels.PokeTime1 = uicontrol(setwin,'Style','text',...
            'String','Box 1 Poke Duration (s)');
        controls.PokeTime1 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box1.PokeTime);
        
        labels.CoolDown1 = uicontrol(setwin,'Style','text',...
            'String','Box 1 Cool Down (s)');
        controls.CoolDown1 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box1.CoolDown);
        
        labels.Withdraw1 = uicontrol(setwin,'Style','text',...
            'String','Need to');
        controls.Withdraw1 = uicontrol(setwin,'Style','checkbox',...
            'String','Withdraw','Value',settings.box1.Withdraw);
        
        % box 2 laser pins
        labels.RightPin2 = uicontrol(setwin,'Style','text',...
            'String','Box 1 Right Beam Pin');
        controls.RightPin2 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box2.RightPin);
        
        labels.LeftPin2 = uicontrol(setwin,'Style','text',...
            'String','Box 1 Left Beam Pin');
        controls.LeftPin2 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box2.LeftPin);
        
        labels.LaserPin2 = uicontrol(setwin,'Style','text',...
            'String','Box 2 Laser Pin');
        controls.LaserPin2 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box2.LaserPin);
        
        labels.PokeTime2 = uicontrol(setwin,'Style','text',...
            'String','Box 2 Poke Duration (s)');
        controls.PokeTime2 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box2.PokeTime);
        
        labels.CoolDown2 = uicontrol(setwin,'Style','text',...
            'String','Box 2 Cool Down (s)');
        controls.CoolDown2 = uicontrol(setwin,'Style','edit',...
            'BackgroundColor','white','String',settings.box2.CoolDown);
        
        labels.Withdraw2 = uicontrol(setwin,'Style','text',...
            'String','Need to');
        controls.Withdraw2 = uicontrol(setwin,'Style','checkbox',...
            'String','Withdraw','Value',settings.box2.Withdraw);
        
        settingnames = fieldnames(controls);
        
        numrows = length(settingnames);
        
        winsize = [200 30+25*numrows];
        set(setwin,'Position',[parentwin(1)+50,...
            parentwin(2)+parentwin(4)-winsize(2)-150,winsize]);
        
        for j = 1:numrows
            ypos = winsize(2)-j*25;
            set(labels.(settingnames{j}),'Position',[05 ypos 90 16]);
            set(controls.(settingnames{j}),'Position',[100 ypos 95 20]);
        end
        
        uicontrol(setwin,'Style','pushbutton','String','OK',...
            'Position',[110 05 30 20],'Callback',{@(x,y) uiresume(setwin)});
        uicontrol(setwin,'Style','pushbutton','String','Cancel',...
            'Position',[145 05 50 20],'Callback',{@(x,y) delete(setwin)});
        
        % wait to set the window
        uiwait(setwin);
        
        % change everything once windows done
        if(ishandle(setwin))
            settings.box1.RightPin= get(controls.RightPin1,'String'); 
            settings.box1.LeftPin = get(controls.LeftPin1,'String');
            settings.box1.LaserPin = get(controls.LaserPin1,'String');
            settings.box1.PokeTime = str2double(get(controls.PokeTime1,'String'));
            settings.box1.CoolDown = str2double(get(controls.CoolDown1,'String'));
            settings.box1.Withdraw = get(controls.Withdraw1,'Value');
            
            settings.box2.RightPin= get(controls.RightPin2,'String'); 
            settings.box2.LeftPin = get(controls.LeftPin2,'String');
            settings.box2.LaserPin = get(controls.LaserPin2,'String');
            settings.box2.PokeTime = str2double(get(controls.PokeTime2,'String'));
            settings.box2.CoolDown = str2double(get(controls.CoolDown2,'String'));
            settings.box2.Withdraw = get(controls.Withdraw2,'Value');
            
            delete(setwin);
        end
    end

        function showerror(err)
            warning(err.message);
            for j = 1:size(err.stack,1)
                fprintf(2,'Error in ==> %s at %d\n',...
                    err.stack(j).name,err.stack(j).line);
            end
        end
end