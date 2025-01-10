classdef helperNRPacketLogger
    properties
        PacketLogs
    end
    
    methods
        function obj = helperNRPacketLogger(numFrames, gNB, UEs)
            % Initialize the packet log storage
            obj.PacketLogs = table();
            
            % Subscribe to packet events
            for ueIdx = 1:length(UEs)
                ue = UEs(ueIdx);
                addlistener(ue, 'PacketReceived', @(src, event)obj.logPacket(event, 'UE'));
                addlistener(gNB, 'PacketTransmitted', @(src, event)obj.logPacket(event, 'gNB'));
            end
        end
        
        function logPacket(obj, event, nodeType)
            % Log packet event with timestamp
            newLog = table(event.PacketID, event.Timestamp, {nodeType}, ...
                           'VariableNames', {'PacketID', 'Timestamp', 'NodeType'});
            obj.PacketLogs = [obj.PacketLogs; newLog];
        end
    end
end
