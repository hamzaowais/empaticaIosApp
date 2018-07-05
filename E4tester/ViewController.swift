//
//  ViewController.swift
//  E4 tester
//

import UIKit
import StompClientLib



struct deviceData {
    var serialNumber :String? = nil;
    var deviceConnectTime: Int? = nil;
    var lastTimeStampPressed: Double? = nil;
}

class ViewController: UITableViewController {
    private var devices: [EmpaticaDeviceManager] = []
    private var deviceDataCollected : [deviceData] = [];
    private var time=0;
    private var timer=Timer();
    private var cout=0;
    private var initialTime=Date().timeIntervalSince1970;
    private var Config  = SettingHelper()
    private var socketClient = StompClientLib();
    private var bvp: [Float] = [];
    private var bvpdiff: [Float] = [];
    private var lastBvp: Float = 0.0;
    private var fs = 64;
    private var processWind = 10;
    private var samplesPerMs:Float = 1000/64;
    private var samplesWind = 10*64;
    
    private var heartRateInst : [Float] = [];
    private var heartRateAvg : [Float] = [];

    
    
    
    
    
    
    
    
    private var allDisconnected : Bool {
        
        return self.devices.reduce(true) { (value, device) -> Bool in
            value && device.deviceStatus == kDeviceStatusDisconnected
        }
    }
    
    
    override func viewDidLoad() {
        
        let url = NSURL(string: self.Config.ACTIVEQHost)!
        socketClient.openSocketWithURLRequest(request: NSURLRequest(url: url as URL) , delegate:self)
        
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            
            EmpaticaAPI.authenticate(withAPIKey: self.Config.APIKEY) { (status, message) in
                
                if status {
                    // "Authenticated"
                    DispatchQueue.main.async {
                        self.discover()
                    }
                }
            }
        }
        
        
        
        DispatchQueue.global(qos: .userInteractive).sync {
            self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.calculateHRMinMax), userInfo: nil, repeats: true);
        }
        
        
        
        
    }
    
    private func discover() {
        EmpaticaAPI.discoverDevices(with: self)
    }
    
    private func disconnect(device: EmpaticaDeviceManager) {
        if device.deviceStatus == kDeviceStatusConnected {
            device.disconnect()
        }
        else if device.deviceStatus == kDeviceStatusConnecting {
            device.cancelConnection()
        }
    }
    
    private func connect(device: EmpaticaDeviceManager) {
        device.connect(with: self)
    }
    private func updateValue1(device : EmpaticaDeviceManager, string : String = "", int: Int) {
        if let section = self.devices.index(of: device) {
            DispatchQueue.main.async {
                let cell = self.tableView.cellForRow(at: IndexPath(row: int, section: section));
                let cell2 = self.tableView.cellForRow(at: IndexPath(row: 7, section: section));
                cell?.detailTextLabel?.text = "\(string)"
                cell?.detailTextLabel?.textColor = UIColor.gray
                let elapsedTime = Int(Date().timeIntervalSince1970)-self.deviceDataCollected[section].deviceConnectTime!;
                cell2?.detailTextLabel?.text = "\(elapsedTime)"
                
                let cell1 = self.tableView.cellForRow(at: IndexPath(row: 0, section: section))
                
                if !device.allowed {
                    cell1?.detailTextLabel?.text = "NOT ALLOWED"
                    cell1?.detailTextLabel?.textColor = UIColor.orange
                }
                else if string.count > 0 {
                    
                    cell1?.detailTextLabel?.text = "\(self.deviceStatusDisplay(status: device.deviceStatus))"
                    
                    cell1?.detailTextLabel?.textColor = UIColor.gray
                }
                else {
                    
                    cell1?.detailTextLabel?.text = "\(self.deviceStatusDisplay(status: device.deviceStatus))"
                    
                    cell1?.detailTextLabel?.textColor = UIColor.gray
                }
                
            }
        }
    }
    
    private func updateValue(device : EmpaticaDeviceManager, string : String = "") {
        
        if let row = self.devices.index(of: device) {
            
            
            DispatchQueue.main.async {
                
                for cell in self.tableView.visibleCells {
                    
                    if let cell = cell as? DeviceTableViewCell {
                        
                        if cell.device == device {
                            
                            let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: row))
                            
                            if !device.allowed {
                                
                                cell?.detailTextLabel?.text = "NOT ALLOWED"
                                
                                cell?.detailTextLabel?.textColor = UIColor.orange
                            }
                            else if string.count > 0 {
                                
                                cell?.detailTextLabel?.text = "\(self.deviceStatusDisplay(status: device.deviceStatus)) • \(string)"
                                
                                cell?.detailTextLabel?.textColor = UIColor.gray
                            }
                            else {
                                
                                cell?.detailTextLabel?.text = "\(self.deviceStatusDisplay(status: device.deviceStatus))"
                                
                                cell?.detailTextLabel?.textColor = UIColor.gray
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func deviceStatusDisplay(status : DeviceStatus) -> String {
        
        switch status {
            
        case kDeviceStatusDisconnected:
            return "Disconnected"
        case kDeviceStatusConnecting:
            return "Connecting..."
        case kDeviceStatusConnected:
            return "Connected"
        case kDeviceStatusFailedToConnect:
            return "Failed to connect"
        case kDeviceStatusDisconnecting:
            return "Disconnecting..."
        default:
            return "Unknown"
        }
    }
    
    private func restartDiscovery() {
        
        print("restartDiscovery")
        
        guard EmpaticaAPI.status() == kBLEStatusReady else { return }
        
        if self.allDisconnected {
            
            print("restartDiscovery • allDisconnected")
            
            self.discover()
        }
    }
}


extension ViewController: EmpaticaDelegate {
    
    func didDiscoverDevices(_ devices: [Any]!) {
        
        print("didDiscoverDevices")
        
        if self.allDisconnected {
            
            print("didDiscoverDevices • allDisconnected")
            
            self.devices.removeAll()
            self.devices.append(contentsOf: devices as! [EmpaticaDeviceManager])
            
            for device in self.devices {
                var tempVar =  deviceData();
                tempVar.serialNumber = device.serialNumber;
                tempVar.deviceConnectTime=Int(Date().timeIntervalSince1970);
                self.deviceDataCollected.append(tempVar);
            }
            
            DispatchQueue.main.async {
                
                self.tableView.reloadData()
                
                if self.allDisconnected {
                    
                    EmpaticaAPI.discoverDevices(with: self)
                }
            }
        }
    }
    
    func didUpdate(_ status: BLEStatus) {
        
        switch status {
        case kBLEStatusReady:
            print("[didUpdate] status \(status.rawValue) • kBLEStatusReady")
            break
        case kBLEStatusScanning:
            print("[didUpdate] status \(status.rawValue) • kBLEStatusScanning")
            break
        case kBLEStatusNotAvailable:
            print("[didUpdate] status \(status.rawValue) • kBLEStatusNotAvailable")
            break
        default:
            print("[didUpdate] status \(status.rawValue)")
        }
    }
}

extension ViewController: EmpaticaDeviceDelegate {
    
    func didReceiveIBI(_ ibi: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        var someDict = [String: Any]();
        someDict["@type"]="feature";
        someDict["creationTimestamp"]=timestamp;
        someDict["source"]="EMPATICA";
        someDict["feature"]="RR_INTERVAL"
        someDict["value"]=ibi
        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
        if let string = String(data: httpBody, encoding: String.Encoding.utf8){
            socketClient.sendMessage(message: string , toDestination:"/queue/Sampletopic" , withHeaders: nil, withReceipt: nil)
        }
        
        
        let heartrate = (1/ibi)*60;
        
        var someDict1 = [String: Any]();
        someDict["@type"]="feature";
        someDict["creationTimestamp"]=timestamp;
        someDict["source"]="EMPATICA";
        someDict["feature"]="HR_IBI"
        someDict["value"]=heartrate
        guard let httpBody1 = try? JSONSerialization.data(withJSONObject: someDict1, options: []) else { return };
        if let string1 = String(data: httpBody1, encoding: String.Encoding.utf8){
            socketClient.sendMessage(message: string1 , toDestination:"/queue/Sampletopic" , withHeaders: nil, withReceipt: nil)
        }
        
//        var someDict = [String: Any]();
//        someDict["serialNumber"]=device.serialNumber;
//        someDict["timeStamp"]=timestamp
//        someDict["value"]=ibi;
//        someDict["key"]="ibi";
//        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
//        var string = String(data: httpBody, encoding: String.Encoding.utf8)
//
//
//        socketClient.sendMessage(message: string ?? "No Data", toDestination:"/queue/Sampletopic" , withHeaders: nil, withReceipt: nil)
//
        //print(string);
        
        
//        print("heartrate: from the ibi values:")
//        print(heartrate);
        self.updateValue1(device: device, string: "{ \(timestamp) :  \(ibi) secs / \(heartrate) hr}",int: 1);
        
    }
    
    func didReceiveGSR(_ gsr: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        var someDict = [String: Any]();
        someDict["@type"]="feature";
        someDict["creationTimestamp"]=timestamp;
        someDict["source"]="EMPATICA";
        someDict["feature"]="GSR"
        someDict["value"]=gsr
        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
        if let string = String(data: httpBody, encoding: String.Encoding.utf8){
            socketClient.sendMessage(message: string , toDestination:"/queue/Sampletopic" , withHeaders: nil, withReceipt: nil)
        }
        
        
        
//        var someDict = [String: Any]();
//        someDict["serialNumber"]=device.serialNumber;
//        someDict["timeStamp"]=timestamp
//        someDict["value"]=gsr;
//        someDict["key"]="gsr";
//        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
//        var string = String(data: httpBody, encoding: String.Encoding.utf8)
//
////
//        socketClient.sendMessage(message: string ?? "No Data", toDestination:"/queue/Sampletopic" , withHeaders: nil, withReceipt: nil)
        
        //print(string);
        
        
        
        self.updateValue1(device: device, string: "\(String(format: "%.2f", abs(gsr))) µS",int: 2)
    }
    
    func didReceiveBVP(_ bvp: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
//        var someDict = [String: Any]();
//        someDict["serialNumber"]=device.serialNumber;
//        someDict["timeStamp"]=timestamp
//        someDict["value"]=bvp;
//        someDict["key"]="bvp";
        self.bvp.append(bvp);
        self.bvpdiff.append(bvp-self.lastBvp);
        self.lastBvp=bvp;
        
//        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
//        var string = String(data: httpBody, encoding: String.Encoding.utf8)
//
//
//        socketClient.sendMessage(message: string ?? "No Data", toDestination:"/queue/Sampletopic" , withHeaders: nil, withReceipt: nil)
        
        //print(string);
        
        self.updateValue1(device: device, string: "\(String(format: "%.2f", abs(bvp)))", int: 3)
    }
    
    func didReceiveTemperature(_ temp: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        var someDict = [String: Any]();
        someDict["@type"]="feature";
        someDict["creationTimestamp"]=timestamp;
        someDict["source"]="EMPATICA";
        someDict["key"]="temp";
        someDict["feature"]="SKIN_TEMPERATURE"
        someDict["value"]=temp
        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
        if let string = String(data: httpBody, encoding: String.Encoding.utf8){
            socketClient.sendMessage(message: string , toDestination:"/queue/Sampletopic" , withHeaders: nil, withReceipt: nil)
        }
        self.updateValue1(device: device, string: "{ \(temp) }", int: 4);
    }
    
    
    @objc func calculateHRMinMax() {
        
        
        let bvp = self.bvp;
        let bvpdif = self.bvpdiff;
        let lastbvp = Array(bvp.suffix(self.samplesWind));
        let lastbvpdif = Array(bvpdif.suffix(self.samplesWind));
        let minValidIBI : Float = 400;
        
        
        if(lastbvp.count<=20){
            return
        }
        var temp_dx = lastbvp[0];
        var indMin : [Int] = [];
        var indMax : [Int] = [];
        
        
        var ibiValArr : [Float] = [];
        
        for i in 1..<lastbvpdif.count{
            
            if((temp_dx<0 && lastbvpdif[i]<0) || (temp_dx>0 && lastbvpdif[i]>0)){
                
            }
            
            if((temp_dx<0 && lastbvpdif[i]>0) && (lastbvp[i-1]<=0)){
                indMin.append(i);
            }
            
            if((temp_dx>0 && lastbvpdif[i]<0) && (lastbvp[i-1]>=0)){
                indMax.append(i);
            }
            temp_dx=lastbvpdif[i];
        }
        
        for i in 2..<indMin.count{
            let tempVal = Float(indMin[i]-indMin[i-1])*self.samplesPerMs;
            if(tempVal >= minValidIBI){
                ibiValArr.append(tempVal/1000);
            }
        }
        
        func average(nums: [Float]) -> Float {
            
            var total : Float = 0
            //use the parameter-array instead of the global variable votes
            for vote in nums{
                
                total += Float(vote)
                
            }
            
            let votesTotal = Float(nums.count)
            
            var average = total/votesTotal
            return average
        }
        
        
        
        
        let meanIbiValue=average(nums: ibiValArr);
        let hr = 60/meanIbiValue;
        print("hamza");
        print(" hr:");
        print(hr);
        
       
        if(!hr.isNaN){
            self.heartRateInst.append(hr);
            
            
            
            
            var someDict = [String: Any]();
            someDict["@type"]="feature";
            someDict["creationTimestamp"]=NSDate().timeIntervalSince1970;
            someDict["source"]="EMPATICA";
            someDict["feature"]="HR_BVP"
            someDict["value"]=hr
            guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
            if let string = String(data: httpBody, encoding: String.Encoding.utf8){
                socketClient.sendMessage(message: string , toDestination:"/queue/Sampletopic" , withHeaders: nil, withReceipt: nil)
            }
            
            
            if(self.heartRateInst.count>17){
                
                let avgHr=average(nums: Array(self.heartRateInst.suffix(15)));
                self.heartRateAvg.append(avgHr);
                
                print("avg hr:");
                print(avgHr);
                
                
                var someDict1 = [String: Any]();
                someDict["@type"]="feature";
                someDict["creationTimestamp"]=NSDate().timeIntervalSince1970;
                someDict["source"]="EMPATICA";
                someDict["feature"]="HR_BVP_AVG"
                someDict["value"]=avgHr
                guard let httpBody1 = try? JSONSerialization.data(withJSONObject: someDict1, options: []) else { return };
                if let string1 = String(data: httpBody1, encoding: String.Encoding.utf8){
                    socketClient.sendMessage(message: string1 , toDestination:"/queue/Sampletopic" , withHeaders: nil, withReceipt: nil)
                }
                
                
            }
            
        }
        
     
       
        
        
        
        
        
    }
    
    func didReceiveAccelerationX(_ x: Int8, y: Int8, z: Int8, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {


//        var someDict = [String: Any]();
//        someDict["serialNumber"]=device.serialNumber;
//        someDict["timestamp"]=timestamp
//        someDict["accValsx"]=x;
//        someDict["accValsy"]=y;
//        someDict["accValsz"]=z;
//        someDict["key"]="acc";
//        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
//        var string = String(data: httpBody, encoding: String.Encoding.utf8)
//
//        //print(string);
//
//        //print(socketClient.isConnected());
//        socketClient.sendMessage(message: string ?? "No Data", toDestination:"/queue/Sampletopic" , withHeaders: nil, withReceipt: nil)

        //print(string);

        self.updateValue1(device: device, string: "{x: \(x), y: \(y), z: \(z)}" ,int: 5);
        //        print("\(device.serialNumber!) ACC > {x: \(x), y: \(y), z: \(z)}")
    }
    
    func didReceiveBatteryLevel(_ battery: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        self.updateValue1(device: device, string: "{\(battery)}" ,int: 6);
        print("\(device.serialNumber!) {\(battery)}")
        
        
    }
    
    
    
    
    
    
    
    func didReceiveTag(atTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        //print("\(device.serialNumber!) TAG received { \(timestamp) }")
        let date = NSDate(timeIntervalSince1970: timestamp)
        let dayTimePeriodFormatter = DateFormatter()
        dayTimePeriodFormatter.dateFormat = "MMM dd YYYY hh:mm a"
        let dateString = dayTimePeriodFormatter.string(from: date as Date)
        self.updateValue1(device: device, string: "{\(dateString)}" ,int: 8);
        
    }
    
    
    
    func didUpdate( _ status: DeviceStatus, forDevice device: EmpaticaDeviceManager!) {
        
        self.updateValue(device: device)
        
        switch status {
            
        case kDeviceStatusDisconnected:
            
            print("[didUpdate] Disconnected \(device.serialNumber!).")
            
            self.restartDiscovery()
            
            break
            
        case kDeviceStatusConnecting:
            
            print("[didUpdate] Connecting \(device.serialNumber!).")
            break
            
        case kDeviceStatusConnected:
            
            print("[didUpdate] Connected \(device.serialNumber!).")
            break
            
        case kDeviceStatusFailedToConnect:
            
            print("[didUpdate] Failed to connect \(device.serialNumber!).")
            
            self.restartDiscovery()
            
            break
            
        case kDeviceStatusDisconnecting:
            
            print("[didUpdate] Disconnecting \(device.serialNumber!).")
            
            break
            
        default:
            break
            
        }
    }
}

extension ViewController {
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        EmpaticaAPI.cancelDiscovery()
        
       // print(indexPath.section);
        
        let device = self.devices[indexPath.section]
        
        if device.deviceStatus == kDeviceStatusConnected || device.deviceStatus == kDeviceStatusConnecting {
            
            self.disconnect(device: device)
        }
        else if !device.isFaulty && device.allowed {
            
            //todo
            var tempVar =  deviceData();
            tempVar.serialNumber = device.serialNumber;
            tempVar.deviceConnectTime=Int(Date().timeIntervalSince1970);
            self.deviceDataCollected[indexPath.section]=tempVar;
            self.connect(device: device)
            
        }
        
        self.updateValue(device: device)
    }
}

extension ViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return self.devices.count
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let device = self.devices[section]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "device") as? DeviceTableViewCell ?? DeviceTableViewCell(device: device)
        
        cell.device = device
        
        cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        
        cell.textLabel?.text = "E4 \(device.serialNumber!)"
        
        cell.alpha = device.isFaulty || !device.allowed ? 0.2 : 1.0
        cell.backgroundColor=UIColor.orange;
        
        return cell
        
        
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return 9
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        
        let device = self.devices[indexPath.section];
        
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "device") as? DeviceTableViewCell ?? DeviceTableViewCell(device: device)
        
        if(indexPath.row==0){
            
            
            // cell.device = device
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "E4 \(device.serialNumber!)"
            
            cell.alpha = device.isFaulty || !device.allowed ? 0.2 : 1.0
            
            return cell
        }
        
        
        if(indexPath.row==1){
            
            cell.detailTextLabel?.text="hamza"
            cell.detailTextLabel?.textColor = UIColor.orange
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            cell.textLabel?.text = "IBI"
            return cell
        }
        if(indexPath.row==2){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            cell.textLabel?.text = "GSR"
            return cell
        }
        if(indexPath.row==3){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "BVP"
            return cell
            
        }
        if(indexPath.row==4){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "Temp"
            return cell
            
        }
        
        if(indexPath.row==5){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "Acceleration"
            return cell
            
        }
        if(indexPath.row==6){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "Battery level"
            return cell
            
        }
        
        if(indexPath.row==7){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            cell.textLabel?.text = "Time Elapsed:"
            return cell
            
        }
        
        if(indexPath.row==8){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "LastTimeStampPressed:"
            return cell
            
        }
        
        cell.device = device
        cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        cell.textLabel?.text = "E4 \(device.serialNumber!)"
        cell.alpha = device.isFaulty || !device.allowed ? 0.2 : 1.0
        
        return cell
        
        
    }
}

extension ViewController: StompClientLibDelegate {
    
    func stompClientDidConnect(client: StompClientLib!) {
        let topic = "/queue/Sampletopic"
       // print("Socket is Connected : \(topic)")
        socketClient.subscribe(destination: topic)
    }
    
    func stompClientDidDisconnect(client: StompClientLib!) {
        print("Socket is Disconnected")
    }
    
    func stompClientWillDisconnect(client: StompClientLib!, withError error: NSError) {
        
    }
    
    func stompClient(client: StompClientLib!, didReceiveMessageWithJSONBody jsonBody: AnyObject?, withHeader header: [String : String]?, withDestination destination: String) {
        //print("DESTIONATION : \(destination)")
        //print("JSON BODY : \(String(describing: jsonBody))")
    }
    
    func stompClientJSONBody(client: StompClientLib!, didReceiveMessageWithJSONBody jsonBody: String?, withHeader header: [String : String]?, withDestination destination: String) {
       // print("DESTIONATION : \(destination)")
        //print("String JSON BODY : \(String(describing: jsonBody))")
    }
    
    func serverDidSendReceipt(client: StompClientLib!, withReceiptId receiptId: String) {
       // print("Receipt : \(receiptId)")
    }
    
    func serverDidSendError(client: StompClientLib!, withErrorMessage description: String, detailedErrorMessage message: String?) {
        print("Error : \(String(describing: message))")
    }
    
    func serverDidSendPing() {
        print("Server Ping")
    }
}


class DeviceTableViewCell : UITableViewCell {
    
    var device : EmpaticaDeviceManager
    
    init(device: EmpaticaDeviceManager) {
        
        self.device = device
        
        super.init(style: UITableViewCellStyle.value1, reuseIdentifier: "device")
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        fatalError("init(coder:) has not been implemented")
    }
}









