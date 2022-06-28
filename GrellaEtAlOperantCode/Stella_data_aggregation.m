%%
% get your directory
[mydir]=uigetdir;

% get the filenames
pullfiles=getAllFiles(mydir,'.mat');

% first two are root, the rest are good files... may need to designate the
% filetypes here by asking whether the files are .mat files

for k=1:length(pullfiles)
    myfile=load(pullfiles{k});
    session(k)=myfile.session;
end

%% Good ways to plot pokes etc.
% this plots a single session
figure;



mysession=session(6);
pokes1=mysession.box1.events(:,1);
pokes2=mysession.box1.events(:,2);
pokes3=abs(mysession.box1.events(:,4))>10;
zaps=mysession.box1.events(:,5);
zaps(zaps==0)=nan;

plot(cumsum(pokes1));
hold on;
plot(cumsum(pokes2));
plot(cumsum(pokes3));
plot(zaps-5,'k*');
legend('front pokes','back pokes','rolly','zaps')
title(mysession.box1.ratname);
xlim([0 length(pokes1)]);

%%
% more plots for a single session
subplot(4,2,8);
pokes1=session.box2.events(:,1);
pokes2=session.box2.events(:,2);
pokes3=abs(session.box2.events(:,4))>10;
zaps=session.box2.events(:,5);
zaps(zaps==0)=nan;

plot(cumsum(pokes1));
hold on;
plot(cumsum(pokes2));
plot(cumsum(pokes3));
plot(zaps-5,'k*');
%legend('front pokes','back pokes','rolly','zaps')
title(session.box2.ratname);
xlim([0 length(pokes1)]);

%% numbers we need
% this aggregates all animals across all sessions
% you'll want to add more fields to this struct
clear recordings;
cumnum=1;
for i=1:length(session)
    %session(i).session.box1.laserpulses=[];
    session(i).box1.filename=session(i).comment;
    session(i).box1.date=datestr(session(i).date);
    session(i).box1.settings=session(i).settings.box1;
    session(i).box1.boxnum=1;
    if isfield(session(i).box1,'lickevents')
        tmpsess=rmfield(session(i).box1,'lickevents');
        tmpsess.events=session(i).box1.lickevents;
        try
            tmpsess.laserpulses=tmpsess.events(tmpsess.events(:,3)==1,4);
        catch
            tmpsess.laserpulses=[];
        end
        recordings(cumnum)=tmpsess;
    else
        recordings(cumnum)=session(i).box1;
    end
    cumnum=cumnum+1;
    session(i).box2.filename=session(i).comment;
    session(i).box2.date=datestr(session(i).date);
    session(i).box2.settings=session(i).settings.box2;
    session(i).box2.boxnum=2;
    if isfield(session(i).box2,'lickevents')
        tmpsess=rmfield(session(i).box2,'lickevents');
        tmpsess.events=session(i).box2.lickevents;
        try
            tmpsess.laserpulses=tmpsess.events(tmpsess.events(:,3)==1,4);
        catch
            tmpsess.laserpulses=[];
        end
        recordings(cumnum)=tmpsess;
    else
        recordings(cumnum)=session(i).box2;
    end
    cumnum=cumnum+1;
end

recordings(cellfun(@(a) isempty(a), {recordings.events}))=[];

%% This aggregates some averages for each session like...

% total counts for each port (number of pokes, or cumulitive seconds per port
% total errors: how many pokes are there with no stim?

% overall rolly counts, poke initates, withdraws and stims


for i=1:length(recordings)
    

    try
        recordings(i).totalzaps=sum(recordings(i).events(:,5));
    end
    try
        recordings(i).totalzaps=size(recordings(i).laserpulses,1);
    end
    if isempty(recordings(i).totalzaps)
        recordings(i).totalzaps=0;
    end
    % start pokes
    recordings(i).frontpokes=sum(diff(recordings(i).events(:,1))==1);
    recordings(i).frontwithdraws=sum(diff(recordings(i).events(:,1))==-1);
    
    % back pokes
    recordings(i).backpokes=sum(diff(recordings(i).events(:,2))==1);
    recordings(i).backwithdraws=sum(diff(recordings(i).events(:,2))==-1);

    % rollyseconds
    recordings(i).rollyseconds=sum(recordings(i).events(:,4)>15);
    recordings(i).rollydistance=sum(abs(diff(recordings(i).events(:,3))))/400;
    % rolly initiations
    recordings(i).rollystarts=sum(diff(recordings(i).events(:,4)>15,1)==1);
    
    try
    recordings(i).sessionduration=(recordings(i).events(end,6)-recordings(i).events(2,6))/60;
    catch
        recordings(i).sessionduration=0;
    end
    % ande cleanign up metadata
    recordings(i).ratname=lower(recordings(i).ratname);
    
    if contains(recordings(i).filename,'tag')
        startind=strfind(lower(recordings(i).filename),'tag');
        recordings(i).sesstype=recordings(i).filename(startind:startind:4);
    elseif contains(recordings(i).filename,'train')
        recordings(i).sesstype='train';
    end
    try
        recordings(i).lasermode=recordings(i).settings.lasermode;
    catch
        recordings(i).lasermode='Front poke';
    end
    
end

%% export struct as an excel doc

excelPrep=struct2table(recordings);
excelPrep.laserpulses=[]; excelPrep.events=[];
excelPrep.settings=[];

myfilename=['StellaDataFull' date '.xlsx'];
mydir=uigetdir;
writetable(excelPrep,fullfile(mydir,myfilename));

%%
% now to plot all these out
% you can plot this out on your onw
% helpful functions:
% struct2cell
% cell2mat
% cellfun



    
