classdef customPacketLossScheduler < nrScheduler
    % Custom Proportional Fair scheduler for 5G NR

    properties (Access = private)
        AverageThroughput % Map from RNTI to average throughput
        HARQProcesses % Map from RNTI to HARQ process state
    end

    methods
        function obj = myCustomEarliestDeadlineFirstScheduler()
            % Constructor to initialize the AverageThroughput map
            obj.AverageThroughput = containers.Map('KeyType', 'double', 'ValueType', 'double');
        end
    end

    methods (Access = protected)
        function dlAssignments = scheduleNewTransmissionsDL(obj, timeResource, frequencyResource, schedulingInfo)
            % Schedule new DL transmissions using Proportional Fair scheduling
            % Get eligible UEs and available RBGs
            global packetloss;
           

            eligibleUEs = schedulingInfo.EligibleUEs;
            numEligibleUEs = numel(eligibleUEs);
            if numEligibleUEs == 0
                dlAssignments = []; % No UEs to schedule
                return;
            end

            % Find available RBGs
            availableRBGs = find(frequencyResource == 0);
            numAvailableRBGs = numel(availableRBGs);
            disp(['Total RBGs: ', num2str(length(frequencyResource))]);
            disp(['Number of Available RBGs: ', num2str(numAvailableRBGs)]);
            disp(frequencyResource);

       


            if numAvailableRBGs == 0
                dlAssignments = []; % No resources to allocate
                return;
            end


            packet = zeros(1, numEligibleUEs);
            % Initialize arrays to store PF metrics
            % For each eligible UE, compute PF metric
            for i = 1:numEligibleUEs
                ueRNTI = eligibleUEs(i);
                packet(i) = packetloss(ueRNTI);


                % Estimate instantaneous data rate based on channel conditions
                % For simplicity, we'll assign random MCS indices 
              
                   % Compute PF metric
            end
            % Sort UEs based on PF metric

            [~, sortedIndices] = sort(packet, 'ascend');
                      

            sortedUEs = eligibleUEs(sortedIndices);

            % Allocate resources to UEs in order of PF metric
            dlAssignments = [];
            currentRBGIndex = 1;
            totalRemainingRBGs = numAvailableRBGs;
            % Loop through sorted UEs and assign resources
            for idx = 1:numEligibleUEs
                disp(["Position in sorted array: ", num2str(idx)]);
                ueRNTI = sortedUEs(idx);
                disp(["RNTI :", num2str(ueRNTI)]);
                
                disp(packet(sortedIndices(idx)));
                % Determine number of RBGs to assign proportionally
                if packet(sortedIndices(idx)) > 0 & (numEligibleUEs-idx) > 0
                 proportion = 1 - packet(sortedIndices(idx)) / sum(packet(sortedIndices(idx:end)));
                 proportion = min(proportion,0.4);
                elseif (numEligibleUEs - idx) == 0
                    proportion = 1;
                else
                    proportion = 0.4;
                end
              
                numRBGsToAssign = max(floor((proportion * totalRemainingRBGs)+0.5), 1); % At least 1 RBG
                
                % Check if enough RBGs are left
                if currentRBGIndex + numRBGsToAssign - 1 > numAvailableRBGs
                    numRBGsToAssign = numAvailableRBGs - currentRBGIndex + 1;
                end

                % Assign RBGs to this UE
                %EDW ALLAZEI H TIMH TWN RBGs
                assignedRBGs = availableRBGs(currentRBGIndex : currentRBGIndex + numRBGsToAssign - 1);
                disp(["Assigned :", num2str(assignedRBGs)]);
                currentRBGIndex = currentRBGIndex + numRBGsToAssign;
                totalRemainingRBGs = totalRemainingRBGs - numRBGsToAssign;

                % Update frequency allocation for this UE
                FrequencyAllocation = zeros(1, length(frequencyResource), 'double');
                FrequencyAllocation(assignedRBGs) = 1;
                % Get UE context for precoder
                ueContext = obj.UEContext(ueRNTI);
                
                % Handle precoder
                if isempty(ueContext.CSIMeasurementDL.CSIRS.W)
                    precoder = eye(1, 'double'); % Default precoder as [1 x 1]
                else
                    precoder = ueContext.CSIMeasurementDL.CSIRS.W;
                end

                % Enforce precoder dimensions
                [numLayers, ngnbTx] = size(precoder);
                if numLayers == 0 || ngnbTx == 0
                    precoder = eye(1, 'double'); % Default [1 x 1] matrix
                end

                % Create the assignment structure
                assignment.RNTI = double(ueRNTI);
                assignment.FrequencyAllocation = double(FrequencyAllocation);
                assignment.W = double(precoder);
                assignment.MCSIndex = double(0);

                % Add this assignment to the list
                dlAssignments = [dlAssignments; assignment];

                
                % Break if no RBGs left
                if currentRBGIndex > numAvailableRBGs
                    break;
                end

            end

        end



    
    end
end
