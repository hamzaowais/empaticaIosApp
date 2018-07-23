//
//  ViewController.swift
//  E4 tester
//

import UIKit
import StompClientLib
import Charts;



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
    
    private var flag=1;
    var hostaddress=String();
    var messageBrokerConnection=0;
    
    var bluetoothConnection = -1;
    
    
    
    @IBOutlet weak var lineChartView: LineChartView!
    
    
    
    private var allDisconnected : Bool {
        
        return self.devices.reduce(true) { (value, device) -> Bool in
            value && device.deviceStatus == kDeviceStatusDisconnected
        }
    }
    
    
    override func viewDidLoad() {
        
        print(hostaddress);
        
        let url = NSURL(string: "ws://172.31.198.181:61614")!
        //let url = NSURL(string: hostaddress)!
        print(url);
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
                }else{
                    
                }
            }
        }
        
        
        
        DispatchQueue.global(qos: .userInteractive).sync {
            self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.calculateHRMinMax), userInfo: nil, repeats: true);
        }
        
        

        
        
    }
    
    func SetChartValues(){
        
    
        let bvp = self.bvp;
        let bvpdif = self.bvpdiff;
        let lastbvp = Array(bvp.suffix(self.samplesWind));
        let lastbvpdif = Array(bvpdif.suffix(self.samplesWind));
        let minValidIBI : Float = 400;
        
        
        print(socketClient.connection)
        
        if(lastbvp.count<=20){
            return
        }
        
        
        let values1 = (0..<lastbvpdif.count).map { (i) -> ChartDataEntry in
            var value: Double = Double(i);
            var temp = lastbvpdif[i];
            let bvpvall = Double(temp)
            return ChartDataEntry(x: value, y:bvpvall);
            
        }
        let set1 = LineChartDataSet(values: values1, label: "Blood Volume Pulse");
        set1.circleRadius=0;
        set1.fillColor = UIColor.blue
        set1.drawFilledEnabled = true
        
        let data = LineChartData(dataSet:set1);
        
        self.lineChartView.data=data;
        self.lineChartView.drawBordersEnabled = false
        self.lineChartView.backgroundColor=UIColor.white;
        
	
        
        
        
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
        if var section = self.devices.index(of: device) {
            section=section+1;
            DispatchQueue.main.async {
                let cell = self.tableView.cellForRow(at: IndexPath(row: int, section: section));
                let cell2 = self.tableView.cellForRow(at: IndexPath(row: 7, section: section));
                cell?.detailTextLabel?.text = "\(string)"
                cell?.detailTextLabel?.textColor = UIColor.gray
                let elapsedTime = Int(Date().timeIntervalSince1970)-self.deviceDataCollected[section-1].deviceConnectTime!;
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
        
        if var row = self.devices.index(of: device) {
            
            row=row+1;
            
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
            print("[didUpdate] status \(status.rawValue) • kBLEStatusReady");
            bluetoothConnection=0;
            break
        case kBLEStatusScanning:
            print("[didUpdate] status \(status.rawValue) • kBLEStatusScanning");
            bluetoothConnection=1;
            break
        case kBLEStatusNotAvailable:
            print("[didUpdate] status \(status.rawValue) • kBLEStatusNotAvailable")
            bluetoothConnection=2;
            break
        default:
            bluetoothConnection=3;
            print("[didUpdate] status \(status.rawValue)")
        }
    }
}

extension ViewController: EmpaticaDeviceDelegate {
    
    func didReceiveIBI(_ ibi: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        var someDict = [String: Any]();
        someDict["@type"]="feature";
        someDict["creationTimestamp"]=timestamp*1000;
        someDict["source"]="EMPATICA";
        someDict["feature"]="RR_INTERVAL"
        someDict["value"]=ibi
        
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
        if let string = String(data: httpBody, encoding: String.Encoding.utf8){
            socketClient.sendMessage(message: string , toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
        }
        
        
        let heartrate = (1/ibi)*60;
        
        //        var someDict1 = [String: Any]();
        //        someDict["@type"]="feature";
        //        someDict["creationTimestamp"]=timestamp*1000;
        //        someDict["source"]="EMPATICA";
        //        someDict["feature"]="HR_IBI"
        //        someDict["value"]=heartrate
        //        guard let httpBody1 = try? JSONSerialization.data(withJSONObject: someDict1, options: []) else { return };
        //        if let string1 = String(data: httpBody1, encoding: String.Encoding.utf8){
        //            socketClient.sendMessage(message: string1 , toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
        //        }
        
        //        var someDict = [String: Any]();
        //        someDict["serialNumber"]=device.serialNumber;
        //        someDict["timeStamp"]=timestamp
        //        someDict["value"]=ibi;
        //        someDict["key"]="ibi";
        //        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
        //        var string = String(data: httpBody, encoding: String.Encoding.utf8)
        //
        //
        //        socketClient.sendMessage(message: string ?? "No Data", toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
        //
        //print(string);
        
        
        //        print("heartrate: from the ibi values:")
        //        print(heartrate);
        self.updateValue1(device: device, string: "{ \(timestamp) :  \(ibi) secs / \(heartrate) hr}",int: 1);
        
    }
    
    func didReceiveGSR(_ gsr: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        var someDict = [String: Any]();
        someDict["@type"]="feature";
        someDict["creationTimestamp"]=timestamp*1000;
        someDict["source"]="EMPATICA";
        someDict["feature"]="GSR"
        someDict["value"]=gsr
        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
        if let string = String(data: httpBody, encoding: String.Encoding.utf8){
            socketClient.sendMessage(message: string , toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
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
        //        socketClient.sendMessage(message: string ?? "No Data", toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
        
        //print(string);
        
        
        
        self.updateValue1(device: device, string: "\(String(format: "%.2f", abs(gsr))) µS",int: 2)
    }
    
    func didReceiveBVP(_ bvp: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        
        var someDict = [String: Any]();
        someDict["@type"]="feature";
        someDict["creationTimestamp"]=timestamp*1000;
        someDict["source"]="EMPATICA";
        someDict["feature"]="BVP"
        someDict["value"]=bvp
        
        
        self.bvp.append(bvp);
        self.bvpdiff.append(bvp-self.lastBvp);
        self.lastBvp=bvp;
        
        self.flag=0;
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
        if let string = String(data: httpBody, encoding: String.Encoding.utf8){
            socketClient.sendMessage(message: string , toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
        }
        
        
        
        //        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
        //        var string = String(data: httpBody, encoding: String.Encoding.utf8)
        //
        //
        //        socketClient.sendMessage(message: string ?? "No Data", toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
        
        //print(string);
        
        self.updateValue1(device: device, string: "\(String(format: "%.2f", abs(bvp)))", int: 3)
    }
    
    func didReceiveTemperature(_ temp: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        var someDict = [String: Any]();
        someDict["@type"]="feature";
        someDict["creationTimestamp"]=timestamp*1000;
        someDict["source"]="EMPATICA";
        someDict["feature"]="SKIN_TEMPERATURE"
        someDict["value"]=temp
        
        //        print("templreture");
        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
        if let string = String(data: httpBody, encoding: String.Encoding.utf8){
            socketClient.sendMessage(message: string , toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
        }
        self.updateValue1(device: device, string: "{ \(temp) }", int: 4);
    }
    
    
    @objc func calculateHRMinMax() {
        
        
        SetChartValues();
        
        if (self.flag==1){
            return
        }
        
        self.flag=1;
        let bvp = self.bvp;
        let bvpdif = self.bvpdiff;
        let lastbvp = Array(bvp.suffix(self.samplesWind));
        let lastbvpdif = Array(bvpdif.suffix(self.samplesWind));
        let minValidIBI : Float = 400;
        
        
        print(socketClient.connection)
        
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
        if(self.devices.count>0){
            self.updateValue1(device: self.devices[0], string: "\(hr)",int: 9);
            self.updateValue1(device: self.devices[0], string: "40",int: 11);
        }
        
        
        
        
        if(!hr.isNaN){
            self.heartRateInst.append(hr);
            
            
            
            
            //            var someDict = [String: Any]();
            //            someDict["@type"]="feature";
            //            someDict["creationTimestamp"]=NSDate().timeIntervalSince1970;
            //            someDict["source"]="EMPATICA";
            //            someDict["feature"]="AVG_HEART_RATE"
            //            someDict["value"]=hr
            //            guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
            //            let string = String(data: httpBody, encoding: String.Encoding.utf8)
            //            socketClient.sendMessage(message: string! , toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
            
            var someDict1 = [String: Any]();
            someDict1["@type"]="feature";
            someDict1["creationTimestamp"]=(NSDate().timeIntervalSince1970+1)*1000;
            someDict1["source"]="EMPATICA";
            someDict1["feature"]="HEART_RATE"
            someDict1["value"]=hr
            guard let httpBody1 = try? JSONSerialization.data(withJSONObject: someDict1, options: []) else { return };
            let string1 = String(data: httpBody1, encoding: String.Encoding.utf8)
            socketClient.sendMessage(message: string1! , toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
            
            
            
            
            
            if(self.heartRateInst.count>17){
                
                let avgHr=average(nums: Array(self.heartRateInst.suffix(15)));
                self.heartRateAvg.append(avgHr);
                
                
                if(self.devices.count>0){
                    self.updateValue1(device: self.devices[0], string: "\(avgHr)",int: 10);
                }
                
                
                
                var someDict = [String: Any]();
                someDict["@type"]="feature";
                someDict["creationTimestamp"]=NSDate().timeIntervalSince1970*1000;
                someDict["source"]="EMPATICA";
                someDict["feature"]="AVG_HEART_RATE"
                someDict["value"]=avgHr
                guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
                let string = String(data: httpBody, encoding: String.Encoding.utf8)
                socketClient.sendMessage(message: string! , toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
                
                print("avg hr:");
                print(avgHr);
                
                
                
                
            }
            
        }
        
        
        
    }
    
    func didReceiveAccelerationX(_ x: Int8, y: Int8, z: Int8, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        var someDict = [String: Any]();
        someDict["@type"]="feature";
        someDict["creationTimestamp"]=timestamp*1000;
        someDict["source"]="EMPATICA";
        someDict["feature"]="accx"
        someDict["value"]=x
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return };
        if let string = String(data: httpBody, encoding: String.Encoding.utf8){
            socketClient.sendMessage(message: string , toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
        }
        
        var someDict1 = [String: Any]();
        someDict1["@type"]="feature";
        someDict1["creationTimestamp"]=timestamp*1000;
        someDict1["source"]="EMPATICA";
        someDict1["feature"]="accy"
        someDict1["value"]=y
        
        guard let httpBody1 = try? JSONSerialization.data(withJSONObject: someDict1, options: []) else { return };
        if let string1 = String(data: httpBody1, encoding: String.Encoding.utf8){
            socketClient.sendMessage(message: string1 , toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
        }
        
        
        var someDict2 = [String: Any]();
        someDict1["@type"]="feature";
        someDict1["creationTimestamp"]=timestamp*1000;
        someDict1["source"]="EMPATICA";
        someDict1["feature"]="accz"
        someDict1["value"]=z
        
        guard let httpBody2 = try? JSONSerialization.data(withJSONObject: someDict1, options: []) else { return };
        if let string2 = String(data: httpBody2, encoding: String.Encoding.utf8){
            socketClient.sendMessage(message: string2 , toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
        }
        
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
        //print(socketClient.isConnected());
        //        socketClient.sendMessage(message: string ?? "No Data", toDestination:"/topic/DataMessage.JSON" , withHeaders: nil, withReceipt: nil)
        
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
        if(indexPath.section == 0){
            return;
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        EmpaticaAPI.cancelDiscovery()
        messageBrokerConnection=4;
        
        // print(indexPath.section);
        
        let device = self.devices[indexPath.section-1]
        
        if device.deviceStatus == kDeviceStatusConnected || device.deviceStatus == kDeviceStatusConnecting {
            
            self.disconnect(device: device)
        }
        else if !device.isFaulty && device.allowed {
            
            //todo
            var tempVar =  deviceData();
            tempVar.serialNumber = device.serialNumber;
            tempVar.deviceConnectTime=Int(Date().timeIntervalSince1970);
            self.deviceDataCollected[indexPath.section-1]=tempVar;
            self.connect(device: device)
            
        }
        
        self.updateValue(device: device)
    }
}

extension ViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return self.devices.count+1;
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if(section == 0){
            
            let view = UIView()
            view.backgroundColor = UIColor.clear
            return view
            
        }
        
        let device = self.devices[section-1]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "device") as? DeviceTableViewCell ?? DeviceTableViewCell(device: device)
        
        cell.device = device
        
        cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        
        cell.textLabel?.text = "E4 \(device.serialNumber!)"
        
        cell.alpha = device.isFaulty || !device.allowed ? 0.2 : 1.0
        cell.backgroundColor=UIColor.orange;
        
        return cell
        
        
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if(section==0){
            return 4;
        }
        return 13
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if(indexPath.section==0){
            
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "device", for: indexPath)
            
            if(indexPath.row == 0){
                print(socketClient.connection);
                var tempstr = "ActiveMQ Connection hosted at: ";
                cell.textLabel?.text = tempstr+hostaddress;
                if(socketClient.connection == true){
                    cell.detailTextLabel?.text="Connected";
                    cell.detailTextLabel?.textColor = UIColor.gray
                    cell.imageView?.image = UIImage(named: "greenball.png");
                    return cell;
                }else{
                    cell.detailTextLabel?.text="Disconnected";
                    cell.detailTextLabel?.textColor = UIColor.gray
                    cell.imageView?.image = UIImage(named: "redball");
                }
                
                
            }
            if(indexPath.row == 1){
                cell.textLabel?.text = "Bluetooth Status:";
                if(messageBrokerConnection==0){
                    cell.detailTextLabel?.text="Ready and Scanning for Devices";
                    cell.detailTextLabel?.textColor = UIColor.gray
                    cell.imageView?.image = UIImage(named: "greenball.png");
                }else if(messageBrokerConnection==1) {
                    cell.detailTextLabel?.text="Ready and Scanning for Devices";
                    cell.detailTextLabel?.textColor = UIColor.gray
                    cell.imageView?.image = UIImage(named: "greenball.png");
                }else if(messageBrokerConnection==2){
                    cell.detailTextLabel?.text="Turn on the Bluetooth";
                    cell.detailTextLabel?.textColor = UIColor.gray
                    cell.imageView?.image = UIImage(named: "redball.png");
                }else if(messageBrokerConnection==4){
                    cell.detailTextLabel?.text="Connection with Empatica Device Established, Scanning Stoped.";
                    cell.detailTextLabel?.textColor = UIColor.gray
                    cell.imageView?.image = UIImage(named: "greenball.png");
                }else{
                    cell.detailTextLabel?.text="Bluetooth Not Ready.";
                    cell.detailTextLabel?.textColor = UIColor.gray
                    cell.imageView?.image = UIImage(named: "redball.png");
                }
            }
            if(indexPath.row == 2){
                
                
                cell.textLabel?.text = "The number of Empatica bands Connected: " + String(self.devices.count );
                if(self.devices.count > 0){
                    cell.imageView?.image = UIImage(named: "greenball.png");
                }else{
                    cell.imageView?.image = UIImage(named: "redball.png");
                }
            }
            
            if(indexPath.row == 3){
                
                
                cell.textLabel?.text = "Click Here Calculate the Resting Heart Rate";
                cell.detailTextLabel?.text="";
                
            }
            
            
            
            return cell
            
            
//            let indexPath = IndexPath(row: indexPath.row, section: indexPath.section)
//            let cell = tableView.cellForRow(at: indexPath)
//
//            cell?. = "hamza";
//            return cell!;
            
        }
        
        
        let device = self.devices[indexPath.section-1];
        
        
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
            cell.imageView?.image = UIImage(named: "ibi1.png");
            return cell
        }
        if(indexPath.row==2){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            cell.textLabel?.text = "GSR"
            cell.imageView?.image = UIImage(named: "sweat.png");
            return cell
        }
        if(indexPath.row==3){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "BVP"
            cell.imageView?.image = UIImage(named: "gsr.png");
            return cell
            
        }
        if(indexPath.row==4){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "Temp"
            cell.imageView?.image = UIImage(named: "temp.png");
            return cell
            
        }
        
        if(indexPath.row==5){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "Acceleration"
            cell.imageView?.image = UIImage(named: "accel.png");
            return cell
            
        }
        if(indexPath.row==6){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.imageView?.image = UIImage(named: "battery.png");
            cell.textLabel?.text = "Battery level"
            return cell
            
        }
        
        if(indexPath.row==7){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            cell.textLabel?.text = "Time Elapsed:"
            cell.imageView?.image = UIImage(named: "time1.png");
            return cell
            
        }
        
        if(indexPath.row==8){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "LastTimeStampPressed:"
            cell.imageView?.image = UIImage(named: "time2.png");
            return cell
            
        }
        if(indexPath.row==8){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "LastTimeStampPressed:"
            
            return cell
            
        }
        if(indexPath.row==9){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "Instantaneous Heart Rate"
            cell.imageView?.image = UIImage(named: "hr.png");
            return cell
            
        }
        if(indexPath.row==10){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "Average Heart Rate"
            cell.imageView?.image = UIImage(named: "hr.png");
            return cell
            
        }
        if(indexPath.row==11){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "Cognitive Work Load"
            cell.imageView?.image = UIImage(named: "stress.png");
            return cell
            
        }
        if(indexPath.row==13){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "Instantaneous Heart Rate - Peak Detection"
            cell.imageView?.image = UIImage(named: "hr.png");
            return cell
            
        }
        if(indexPath.row==13){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "Average Heart Rate - Peak Detection"
            cell.imageView?.image = UIImage(named: "hr.png");
            return cell
            
        }
        if(indexPath.row==13){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "Cognitive Work Load"
            cell.imageView?.image = UIImage(named: "stress.png");
            return cell
            
        }
        if(indexPath.row==12){
            
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 18)
            
            cell.textLabel?.text = "Graphs"
            cell.backgroundColor=UIColor.orange
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
        let topic = "/topic/DataMessage.JSON1"
        print("Socket is Connected : \(topic)")
        socketClient.subscribe(destination: topic)
    }
    
    func stompClientDidDisconnect(client: StompClientLib!) {
        print("Socket is Disconnected")
    }
    
    func stompClientWillDisconnect(client: StompClientLib!, withError error: NSError) {
        
    }
    
    func stompClient(client: StompClientLib!, didReceiveMessageWithJSONBody jsonBody: AnyObject?, withHeader header: [String : String]?, withDestination destination: String) {
        //print("DESTIONATION : \(destination)")
        print("JSON BODY : \(String(describing: jsonBody))")
    }
    
    func stompClientJSONBody(client: StompClientLib!, didReceiveMessageWithJSONBody jsonBody: String?, withHeader header: [String : String]?, withDestination destination: String) {
        // print("DESTIONATION : \(destination)")
        //        print(client.connection);
        print("String JSON BODY : \(String(describing: jsonBody))")
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











