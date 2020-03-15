%% Running data analysis

%%
%%%%%%%%%%%%
%%%%%%%%%%%%%
%%%%%%%%%%%%
%%%%%%%%%%%%%
%%%%%%%%%
load('L:\Dropbox (Eichenbaumers)\Eichenbaumers Team Folder\CogNeuro\Projects\Bladon Squad\Opto\Ramirez opto\Kaitlyn\BlaStim.mat');



%% 
% for retrieval bin into three minute bins instead of 1 and then go out to
% as far as you can go

% first aggregate the running data into a matrix
% matrix will be mouse x run day
runmat=[];
freezmat=[];
zapmat=[];
distmat=[];
for i=1:length(BlaStim)
    try
        runrow=[BlaStim(i).rundata.totaltimeran]./[BlaStim(i).rundata.sessionduration];
        runmat(i,:)=runrow*100;
    catch
        runmat(i,:)=nan;
    end
    try
        freezrow=cell2mat(BlaStim(i).FreezData(3,2:11));
        freezmat(i,:)=freezrow;
    catch
        freezmat(i,:)=nan;
    end
        try
        zaprow=[BlaStim(i).rundata.stims];
        zapmat(i,:)=zaprow;
    catch
        zapmat(i,:)=nan;
        end
    try
        distrow=[BlaStim(i).rundata.totaldist]./[BlaStim(i).rundata.sessionduration];
        distmat(i,:)=distrow;
    catch
        distmat(i,:)=nan;
    end
end

%%
ChRunner=~[BlaStim.isyoked] & ~[BlaStim.iscontrol];
EyRunner=~[BlaStim.isyoked] & [BlaStim.iscontrol];
ChYoked=[BlaStim.isyoked] & ~[BlaStim.iscontrol];
EyYoked=[BlaStim.isyoked] & [BlaStim.iscontrol];

figure;
errorbar(1:6,nanmean(runmat(ChRunner,:)),SEM(runmat(ChRunner,:),1));
hold on;
errorbar([1:6]-.05,nanmean(runmat(EyRunner,:)),SEM(runmat(EyRunner,:),1));
errorbar([1:6]+.05,nanmean(runmat(ChYoked,:)),SEM(runmat(ChYoked,:),1));
errorbar([1:6]-.1,nanmean(runmat(EyYoked,:)),SEM(runmat(EyYoked,:),1));

legend('ChRunner','EyRunner','ChYoked','EyYoked');
legend('boxoff'); box off; xlim([0 7]);
set(gca,'XTick',1:6,'XTickLabel',{'Train1','Train2','Train3','Train4','Opto just after fc','Recall'})
title('% Time Ran')
%%
figure;
errorbar(1:10,nanmean(freezmat(ChRunner,:)),SEM(freezmat(ChRunner,:),1));
hold on;
errorbar([1:10]-.05,nanmean(freezmat(EyRunner,:)),SEM(freezmat(EyRunner,:),1));
errorbar([1:10]+.05,nanmean(freezmat(ChYoked,:)),SEM(freezmat(ChYoked,:),1));
errorbar([1:10]-.1,nanmean(freezmat(EyYoked,:)),SEM(freezmat(EyYoked,:),1));

legend('ChRunner','EyRunner','ChYoked','EyYoked');
legend('boxoff'); box off; title('Freezing Recall')

figure; subplot(2,2,1);
errorbar(1:10,nanmean(freezmat(ChRunner,:)),SEM(freezmat(ChRunner,:),1));
hold on;
errorbar([1:10]+.05,nanmean(freezmat(ChYoked,:)),SEM(freezmat(ChYoked,:),1));
legend('ChRunner','ChYoked');
legend('boxoff'); box off; title('Freezing Recall');
subplot(2,2,2);
errorbar([1:10]-.05,nanmean(freezmat(EyRunner | ChRunner,:)),SEM(freezmat(EyRunner | ChRunner,:),1));
hold on;
errorbar([1:10]+.05,nanmean(freezmat(ChYoked | EyYoked,:)),SEM(freezmat(ChYoked | EyYoked,:),1));
legend('All runners','All yoked');
legend('boxoff'); box off; title('Freezing Recall');

subplot(2,2,3);
errorbar([1:10]-.05,nanmean(freezmat(EyRunner,:)),SEM(freezmat(EyRunner,:),1));
hold on;
errorbar([1:10]+.05,nanmean(freezmat(EyYoked,:)),SEM(freezmat(EyYoked,:),1));
legend('EY Runner','EY yoked');
legend('boxoff'); box off; title('Freezing Recall');


subplot(2,2,4);
errorbar([1:10]-.05,nanmean(freezmat(ChRunner | ChYoked,:)),SEM(freezmat(ChRunner | ChYoked,:),1));
hold on;
errorbar([1:10]+.05,nanmean(freezmat(EyRunner | EyYoked,:)),SEM(freezmat(EyRunner | EyYoked,:),1));
legend('All ChR2','All EYFP');
legend('boxoff'); box off; title('Freezing Recall');
linkaxes
%%
figure;
% some of the zaps didnt get pushed through to the yoked guys
zapmat(zapmat<5)=nan;
errorbar(1:6,nanmean(zapmat(ChRunner,:)),SEM(zapmat(ChRunner,:),1));
hold on;
errorbar([1:6]-.05,nanmean(zapmat(EyRunner,:)),SEM(zapmat(EyRunner,:),1));
%errorbar([1:6]+.05,nanmean(zapmat(ChYoked,:)),SEM(zapmat(ChYoked,:),1));
%errorbar([1:6]-.1,nanmean(zapmat(EyYoked,:)),SEM(zapmat(EyYoked,:),1));

legend('ChRunner','EyRunner','ChYoked','EyYoked');
legend('boxoff'); box off; title('number of zaps')
%set(gca,'XTick',1:6,'XTickLabel',{'Train1','Train2','Train3','Train4','Opto','Recall'})
%%
figure;
% some of the zaps didnt get pushed through to the yoked guys
distmat(distmat<5)=nan;
errorbar(1:6,nanmean(distmat(ChRunner,:)),SEM(distmat(ChRunner,:),1));
hold on;
errorbar([1:6]-.05,nanmean(distmat(EyRunner,:)),SEM(distmat(EyRunner,:),1));
errorbar([1:6]+.05,nanmean(distmat(ChYoked,:)),SEM(distmat(ChYoked,:),1));
errorbar([1:6]-.1,nanmean(distmat(EyYoked,:)),SEM(distmat(EyYoked,:),1));

legend('ChRunner','EyRunner','ChYoked','EyYoked');
legend('boxoff'); box off; title('Distance per minute')

%%
% for these data, it looks like the ch yoked froze less than everyone else
% and the EyRunners and Ch Runners froze the most
% so somehow zapping the runners didnt change how much they froze, but
% zapping the yoked guys reduced their freezing

% maybe for the ch runners, regress running at opto with freezing ammt
figure; plotregression(runmat(ChRunner,5),nanmean(freezmat(ChRunner,2:6),2))
[R,p]=corr(runmat(ChRunner,5),nanmean(freezmat(ChRunner,2:6),2),'rows','complete');
xlabel('% running during opto stim of fear engram');
ylabel('% freezing during post-run recall in fear box')
mytitle=get(gca,'Title');
title(['ChR2 Runners' mytitle.String]);
% not significant

figure; plotregression(runmat(ChYoked,6),nanmean(freezmat(ChYoked,2:6),2));
xlabel('% stimulation during opto stim of fear engram');
ylabel('% freezing during post-run recall in fear box')
mytitle=get(gca,'Title');
title(['ChR2 Yoked' mytitle.String]);
[R,p]=corr(runmat(ChYoked,6),nanmean(freezmat(ChYoked,2:6),2),'rows','complete')
% no interaction

% what about all the animals
figure;scatter(runmat(:,6),nanmean(freezmat(:,2:6),2));
[r,m,b] = regression(runmat(:,6),nanmean(freezmat(:,2:6),2),'one');
hold on; plot([min(runmat(:,6)) max(runmat(:,6))], [min(runmat(:,6)) max(runmat(:,6))]*m+b,'r')
[R,p]=corr(runmat(:,6),nanmean(freezmat(:,2:6),2),'rows','complete');
xlabel('Percent of time ran'); ylabel('percent of time froze');
title('all mice');

%
% now for the ChRunners, whats the distribution look like

figure; histogram(linearize(nanmean(freezmat(:,2:6),2)),20);
title('histogram of freezing percentages')
xlabel('freezing percentage'); ylabel('number of animals');



figure; histogram(runmat(ChRunner | EyRunner,5),10);
title('histogram of freezing percentages')
xlabel('freezing percentage'); ylabel('number of animals');

% run a boxscatter?
design=[ChRunner' EyRunner' ChYoked' EyYoked'];
deltamat=[];
for i=1:4
    thismat=[runmat(design(:,i),6)-runmat(design(:,i),4)];
    thismat(:,2)=i;
    deltamat=[deltamat; thismat];
end



boxScatterplot(deltamat(:,1),deltamat(:,2))
set(gca,'XTickLabel',{'ChRunner','ChYoked','EyRunner','EyYoked'})
set(gcf,'Position',[999   377   534   450])
ylabel('Change in running pre/post shock & stim');

%%
% high and low freezers
% plot ch runners that freeze more than 50% and thoes that run

%































%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%% SFN 2018 ANALYSES %%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% load the freezing data, aggregate
load('L:\Dropbox (Eichenbaumers)\Eichenbaumers Team Folder\CogNeuro\Projects\Bladon Squad\Opto\Ramirez opto\Kaitlyn\KaitlynFreezingData.mat')

myfields=fieldnames(FreezingData);
it=1;
FullFreezing=[];
for i=1:length(myfields)
    thismat=FreezingData.(myfields{i});
    for j=2:size(thismat,2)
        FullFreezing{it,1}=thismat{1,j};
        FullFreezing{it,2}=myfields{i};
        if size(thismat,1)>30
            FullFreezing{it,3}=cell2mat(thismat([7 13 19 25 31 37],j));
        else
            FullFreezing{it,3}=nanmean(cell2mat(thismat(2:end-1,j)));
        end
        it=it+1;
    end
end

[a,b,c]=unique(FullFreezing(:,1));
FreezingShort={[] [] [] [] [] [] [] [] [] [] [] []};
for i=1:length(b)
    % first three cols will be ext1
    mousename=b(i);
    mouseaggregate=FullFreezing(b(i),:);
    % now tack all the subsequent indices onto that
    nextinds=find(c==i);
    if length(nextinds)>1
        for j=2:length(nextinds) % because the first was already found
            mouseaggregate=[mouseaggregate FullFreezing(nextinds(j),2:3)];
        end
    end
    FreezingShort(i,1:length(mouseaggregate))=mouseaggregate;
end
% this makes the file below, but look over the data before saving out
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%    Load the dataset  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
load('L:\Dropbox (Eichenbaumers)\Eichenbaumers Team Folder\CogNeuro\Projects\Bladon Squad\Opto\Ramirez opto\Kaitlyn\KaitlynFreezingShort.mat')

% now load all the running data
load('L:\Dropbox (Eichenbaumers)\Eichenbaumers Team Folder\CogNeuro\Projects\Bladon Squad\Opto\Ramirez opto\Kaitlyn\RunningDataC6.mat')
RunningDataC6=RunningDataC6(1:72); % clip the useless data
load('L:\Dropbox (Eichenbaumers)\Eichenbaumers Team Folder\CogNeuro\Projects\Bladon Squad\Opto\Ramirez opto\Kaitlyn\RunningDataC8.mat')
load('L:\Dropbox (Eichenbaumers)\Eichenbaumers Team Folder\CogNeuro\Projects\Bladon Squad\Opto\Ramirez opto\Kaitlyn\RunningDataC7.mat')

%% now we can start matching them up
% how best to organize this
% well chrono it goes like this:
% mouse prelim run d1 freeze d1 runn d2 freez d2 run d3 freez d3 run d4
% freez d4 run reinst
% could do cell mat, or struct.  I think i'll do a struct cause thats
% already made. Each field can be a mouse
clear FinalStruct
for i=1:length(FreezingShort)
    FinalStruct(i).name=FreezingShort{i,1};
    FinalStruct(i).yoked=contains(FreezingShort{i,1},'yoke','IgnoreCase',1);
    FinalStruct(i).Day1Freez=FreezingShort{i,3};
    FinalStruct(i).Day2Freez=FreezingShort{i,5};
    FinalStruct(i).Day3Freez=FreezingShort{i,7};
    FinalStruct(i).Day4Freez=FreezingShort{i,9};
    FinalStruct(i).PreFreez=FreezingShort{i,11};
    FinalStruct(i).GFP=FreezingShort{i,4}(1:4);
    % now find corresponding running data
    Sessname=FreezingShort{i,1};
    % find session and mouse name
    
    if contains(Sessname,'C6','IgnoreCase',1)
        thisstruct=RunningDataC6;
        indpull=4;
    elseif contains(Sessname,'C7','IgnoreCase',1)
        indpull=5;
        thisstruct=RunningDataC7;
    elseif contains(Sessname,'C8','IgnoreCase',1)
        indpull=5;
        thisstruct=RunningDataC8;
    end
    numstop=find(Sessname==' ',1,'first');
    mousenum=str2double(Sessname(5:numstop-1));
    allnames=struct2cell(thisstruct); allmice=squeeze(allnames(3,:));
    allmicenames=cellfun(@(a) str2double(a(2:end)),allmice);
    allmicenames(allmicenames==0)=nan;
    allmicenames(allmicenames>20)=nan;
    
    % get indices of the session where the session and mouse are right
    mousepull=find(allmicenames==mousenum);
    
    for xt=1:length(mousepull) % four extinguishing sessions
        myname=allnames(indpull,1,mousepull(xt));
        % fix up our name here so no underscores
        tempname=myname{1}'; fullname=tempname(:)'; fullname(fullname=='_')=' ';
        if contains(fullname,'ext 1','IgnoreCase',1) || contains(fullname,'ext1','IgnoreCase',1)...
                || contains(fullname,'pto1','IgnoreCase',1) || contains(fullname,'pto 1','IgnoreCase',1)
            FinalStruct(i).Day1Ext=thisstruct(mousepull(xt));
        elseif contains(fullname,'ext 2','IgnoreCase',1) || contains(fullname,'ext2','IgnoreCase',1)...
                || contains(fullname,'pto2','IgnoreCase',1) || contains(fullname,'pto 2','IgnoreCase',1)
            FinalStruct(i).Day2Ext=thisstruct(mousepull(xt));
        elseif contains(fullname,'ext 3','IgnoreCase',1) || contains(fullname,'ext3','IgnoreCase',1)...
                || contains(fullname,'pto3','IgnoreCase',1) || contains(fullname,'pto 3','IgnoreCase',1)
            FinalStruct(i).Day3Ext=thisstruct(mousepull(xt));
        elseif contains(fullname,'ext 4','IgnoreCase',1) || contains(fullname,'ext4','IgnoreCase',1)...
                || contains(fullname,'pto4','IgnoreCase',1) || contains(fullname,'pto 4','IgnoreCase',1)
            FinalStruct(i).Day4Ext=thisstruct(mousepull(xt));
        end
        % just grab the last file, they all should be the same
        FinalStruct(i).RunFile=thisstruct(mousepull(xt)).filename;
        % right now we're ditching training data
    end
end
  

%%
% okay first recapitulate the dataset

% okay start with the runners cause we have their data
AllCells=struct2cell(FinalStruct);
Runners=cellfun(@(a) logical(a),squeeze(AllCells(2,1,:)));
RunnerStruct=FinalStruct(~Runners);

% ********** reorder runner struct here so you can index independently *******
[~,index] = sortrows({FinalStruct.GFP}.'); FinalStruct = FinalStruct(index); clear index;
RunnerStruct(8) = []; % kill c7 m12

%%
% okay lets get the gfp guys and see if their running relates to freezing
% lets start with day 1
freezy=[]; runnydist=[]; runnytime=[];
for i=1:length(RunnerStruct)
    try freezy(i,1)=nanmean(RunnerStruct(i).Day1Freez); catch, end
    try freezy(i,2)=nanmean(RunnerStruct(i).Day2Freez); catch, end
    try freezy(i,3)=nanmean(RunnerStruct(i).Day3Freez); catch, end
    try freezy(i,4)=nanmean(RunnerStruct(i).Day4Freez); catch, end
    try runnydist(i,1)=RunnerStruct(i).Day1Ext.totaldist/(RunnerStruct(i).Day1Ext.sessionduration*60); catch, end
    try runnydist(i,2)=RunnerStruct(i).Day2Ext.totaldist/(RunnerStruct(i).Day2Ext.sessionduration*60); catch, end
    try runnydist(i,3)=RunnerStruct(i).Day3Ext.totaldist/(RunnerStruct(i).Day3Ext.sessionduration*60); catch, end
    try runnydist(i,4)=RunnerStruct(i).Day4Ext.totaldist/(RunnerStruct(i).Day4Ext.sessionduration*60); catch, end
    try runnytime(i,1)=nanmean(RunnerStruct(i).Day1Ext.events(:,4)>10)*100; catch, end
    try runnytime(i,2)=nanmean(RunnerStruct(i).Day2Ext.events(:,4)>10)*100; catch,  end
    try runnytime(i,3)=nanmean(RunnerStruct(i).Day3Ext.events(:,4)>10)*100; catch,  end
    try runnytime(i,4)=nanmean(RunnerStruct(i).Day4Ext.events(:,4)>10)*100; catch, end

end
runnytime(runnytime==0)=nan;
runnydist(runnydist==0)=nan;


%% running data
midpoint=12;
figure;
ha=errorbar(nanmean(runnydist(1:midpoint,:)),SEM(runnydist(1:midpoint,:)),'Color',[.2771 .3633	.3596]);
hold on; set(ha,'LineWidth',2);
ha=errorbar(nanmean(runnydist(midpoint+1:end,:)),SEM(runnydist(midpoint+1:end,:)),'Color',[.1009 .3211 .5780]);
box off; grid off; set(ha,'LineWidth',2);
xlim([0.5 4.5]); set(gca,'XTick',1:4);
legend('CHR2 Mice','EYFP Mice'); ylabel('Running Dist (Revs/Min)');
xlabel('Extinction Day');
for i=1:4
    [pval]=ranksum(runnydist(1:midpoint,i),runnydist(midpoint+1:end,i))
    pval=round(pval,3);
    if pval<.05 && pval>.01
        text(i-.02,nanmean(runnydist(1:midpoint))+SEM(runnydist(1:midpoint,i))*1.2,'*');
    elseif pval<.01
        text(i-.03,nanmean(runnydist(1:midpoint))+SEM(runnydist(1:midpoint,i))*1.2,'**');
    end
end
ylim([140 350]);

figure;
ha=errorbar(nanmean(runnytime(1:midpoint,:)),SEM(runnytime(1:midpoint,:)),'Color',[.2771 .3633	.3596]);
hold on; set(ha,'LineWidth',2);
ha=errorbar(nanmean(runnytime(midpoint+1:end,:)),SEM(runnytime(midpoint+1:end,:)),'Color',[.1009 .3211 .5780]);
box off; grid off; set(ha,'LineWidth',2);
xlim([0.5 4.5]); set(gca,'XTick',1:4);
legend('CHR2 Mice','EYFP Mice'); ylabel('Running Time (% Time)');
xlabel('Extinction Day');
for i=1:4
    [pval]=ranksum(runnytime(1:midpoint,i),runnytime(midpoint+1:end,i))
    pval=round(pval,3);
    if pval<.05 && pval>.01
        text(i-.02,nanmean(runnytime(1:midpoint))+SEM(runnytime(1:midpoint,i))*1.2,'*','FontSize',20);
    elseif pval<.01
        text(i-.03,nanmean(runnytime(1:midpoint))+SEM(runnytime(1:midpoint,i))*1.2,'**','FontSize',20);
    end
end
ylim([0 35]);
[~,pval]=ttest2(linearize(runnytime(1:midpoint,:)),linearize(runnytime(midpoint+1:end,:)))
%% what about just the first day
freezy=[]; runtime2=[]; rundist2=[];
for i=1:length(RunnerStruct)
    try freezy(i,:)=RunnerStruct(i).Day4Freez; catch, end

    
    try 
        Rundata=RunnerStruct(i).Day4Ext.events;
        thirds=floor((1:size(Rundata,1))/(size(Rundata,1)/6))'+1;
        for th=1:6, runtime2(i,th)=nanmean(Rundata(thirds==th,4)>10)*100; end
    catch 
    end
     try 
        Rundata=RunnerStruct(i).Day4Ext.events;
        thirds=floor((1:size(Rundata,1))/(size(Rundata,1)/6))'+1;
        for th=1:6, rundist2(i,th)=nansum(abs(diff(Rundata(thirds==th,3)))); end
    catch 
     end
   
    

end

rundist2(i,:)=nan;
runtime2(i,:)=nan;
runtime2(runtime2==0)=nan;
rundist2(rundist2==0)=nan;

%%
figure; 
ha=errorbar(nanmean(rundist2(1:midpoint,:)),SEM(rundist2(1:midpoint,:)),'Color',[.2771 .3633	.3596]);
hold on; set(ha,'LineWidth',2);
ha=errorbar(nanmean(rundist2(midpoint+1:end,:)),SEM(rundist2(midpoint+1:end,:)),'Color',[.1009 .3211 .5780]);
box off; grid off; set(ha,'LineWidth',2);
xlim([0.5 6.5]); set(gca,'XTick',1:6);
legend('CHR2 Mice','EYFP Mice'); ylabel('Running Dist (Revs/Min)');
xlabel('Time Within Session'); 
title('Day 1')
% 
for i=1:6
    [pval]=ranksum(rundist2(1:midpoint,i),rundist2(midpoint+1:end,i))
    %[~,pval]=ttest2(runnytime2(1:13,i),runnytime2(14:end,i))
    if pval<.05 && pval>.01
        text(i-.08,nanmean(rundist2(1:midpoint,i))+SEM(rundist2(1:midpoint,i))*1.05,'*','FontSize',24);
    elseif pval<.01
        text(i-.16,nanmean(rundist2(1:midpoint,i))+SEM(rundist2(1:midpoint,i))*1.05,'**','FontSize',24);
    end
end


%%

figure;
ha=errorbar(nanmean(runtime2(1:midpoint,:)), SEM(runtime2(1:midpoint,:)),'Color',[.2771 .3633	.3596]);
hold on; set(ha,'LineWidth',2);
ha=errorbar(nanmean(runtime2(midpoint+1:end,:)),SEM(runtime2(midpoint+1:end,:)),'Color',[.1009 .3211 .5780]);
box off; grid off; set(ha,'LineWidth',2);
xlim([0.5 6.5]); set(gca,'XTick',1:6);
legend('CHR2 Mice','EYFP Mice'); ylabel('Running Time (% of time)');
xlabel('Time Within Session');
title('Day 4');
for i=1:6
    [pval]=ranksum(runtime2(1:midpoint,i),runtime2(midpoint+1:end,i))
    pval=round(pval,3);
    %[~,pval]=ttest2(runnytime2(1:13,i),runnytime2(14:end,i))
    if pval<.05 && pval>.01
        text(i-.07,nanmean(runtime2(1:midpoint,i))+SEM(runtime2(1:midpoint,i))*1.1,'*','FontSize',24);
    elseif pval<.01
        text(i-.14,nanmean(runtime2(1:midpoint,i))+SEM(runtime2(1:midpoint,i))*1.1,'**','FontSize',24);
    end
end


%%
figure; 
ha=errorbar(nanmean(freezy(1:13,:)),SEM(freezy(1:13,:)),'Color',[.2771 .3633	.3596]);
hold on; set(ha,'LineWidth',2);
ha=errorbar(nanmean(freezy(14:end,:)),SEM(freezy(14:end,:)),'Color',[.1009 .3211 .5780]);
box off; grid off; set(ha,'LineWidth',2);
xlim([0.5 4.5]); set(gca,'XTick',1:4);
legend('CHR2 Mice','EYFP Mice'); ylabel('Running Dist (Revs/Min)');
xlabel('Time Within Session'); 
title('Day 2')
% 
for i=1:4
    [pval]=ranksum(freezy(1:13,i),freezy(14:end,i))
    %[~,pval]=ttest2(runnytime2(1:13,i),runnytime2(14:end,i))
    if pval<.05 && pval>.01
        text(i-.08,nanmean(freezy(1:13,i))+SEM(freezy(1:13,i))*1.05,'*','FontSize',20);
    elseif pval<.01
        text(i-.16,nanmean(freezy(1:13,i))+SEM(freezy(1:13,i))*1.05,'**','FontSize',20);
    end
end
