
% first pull the parent directory with all your files
[dirName]=uigetdir;
% get all the files with the format csv... or maybe matlab not sure (.mat)

fileList = getAllFiles(dirName,'csv');
% this is the headers for each cell column in the dataset
excelOut={'Name','1:5 No Freeze','Freeze','5:10 No Freeze','Freeze','10:15 No Freeze','Freeze','15:20 No Freeze','Freeze'};
% the recordings are about
timebins=[0 300 560 860];
for i=1:length(fileList)
    
    
    myname=fileList{i}(find(fileList{i}=='\',1,'last')+1:end-4);
    excelOut{i+1,1}=myname; 
    [a]=importdata([fileList{i}]);
    excelStart=cellfun(@(x) str2double(x), a.textdata(2:end,1));
    excelStart(:,2)=a.data; excelData=unique(excelStart,'rows');
    chop=find(excelStart(:,1)>1120);
    if any(chop), excelStart(chop:end,:)=[]; end
    excelStart=[excelStart; 1120 excelStart(end-2,2)];
    if max(excelStart(1:end-1,1))>860
        % 2 is not freezing start, 1 is freezing start
        % now add in our 5 minute markers
        excelData(1)=0;
        for tb=2:length(timebins)
            slot=find(excelData> timebins(tb),1,'first');
            excelData=[excelData(1:slot-1,:); timebins(tb) excelData(slot-2,2);...
                timebins(tb) excelData(slot-1,2); excelData(slot:end,:)];
        end
        % get the time intervals so they match up for the on time of each
        % now run throguh
        excelData(:,3)=[0; diff(excelData(:,1))]';
        for bl=1:3
            % get our interval for the data were looking at
            blstart=find(excelData(:,1)==timebins(bl),1,'last');
            blend=find(excelData(:,1)==timebins(bl+1),1,'first');
            thisdata=excelData(blstart:blend,:);
            % this is not freezing to freezing (so not freezin gtime)
            excelOut{i+1,bl*2}=round(nansum(thisdata(thisdata(:,2)==1,3)),2);
            % this is freeze to not freeze, or freeze time
            excelOut{i+1,bl*2+1}=round(nansum(thisdata(thisdata(:,2)==2,3)),2);
        end
        blstart=find(excelData(:,1)==timebins(end),1,'last');
        blend=length(excelData(:,1));
        thisdata=excelData(blstart:blend,:);
        % this is not freezing to freezing (so not freezin gtime)
        excelOut{i+1,8}=round(nansum(thisdata(thisdata(:,2)==1,3)),2);
        % this is freeze to not freeze, or freeze time
        excelOut{i+1,9}=round(nansum(thisdata(thisdata(:,2)==2,3)),2);
    else
    end
end

