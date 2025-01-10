classdef customPacketLossScheduler < nrScheduler
    % Custom Proportional Fair scheduler for 5G NR

    methods (Access = protected)
        function dlAssignments = scheduleNewTransmissionsDL(obj, ~, frequencyResource, schedulingInfo)
            % Schedule new DL transmissions using Proportional Fair scheduling
            % Get eligible UEs and available RBGs
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

            global packetloss;
            if numAvailableRBGs == 0
                dlAssignments = []; % No resources to allocate
                return;
            end

            % Initialize arrays to store PLS metrics
            % For each eligible UE, compute PLS metric
            packet = zeros(1, numEligibleUEs);
            for i = 1:numEligibleUEs
                ueRNTI = eligibleUEs(i);
                packet(i) = 1/packetloss(ueRNTI);
            end

            % Sort UEs based on PLS metric
            [~, sortedIndices] = sort(packet, 'descend');                
            sortedUEs = eligibleUEs(sortedIndices);

            % Allocate resources to UEs in order of PF metric
            dlAssignments = [];
            currentRBGIndex = 1;
            totalRemainingRBGs = numAvailableRBGs;
            % Loop through sorted UEs and assign resources
            for idx = 1:numEligibleUEs
                ueRNTI = sortedUEs(idx);

                % Determine proportion of RBGs to assign
                proportion = packet(sortedIndices(idx)) / sum(packet(sortedIndices(idx:end)));
                numRBGsToAssign = max(floor(proportion * totalRemainingRBGs), 1); % At least 1 RBG

                % Check if enough RBGs are left
                if currentRBGIndex + numRBGsToAssign - 1 > numAvailableRBGs
                    numRBGsToAssign = numAvailableRBGs - currentRBGIndex + 1;
                end

                % Assign RBGs to this UE
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
