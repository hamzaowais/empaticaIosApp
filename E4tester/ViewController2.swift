//
//  ViewController.swift
//  E4 tester
//

import UIKit

import StompClientLib




// - didReceiveIBI:withTimestamp:fromDevice:
// - didReceiveGSR:withTimestamp:fromDevice:
// - didReceiveBVP:withTimestamp:fromDevice:
// - didReceiveTemperature:withTimestamp:fromDevice:
// - didReceiveAccelerationX:y:z:withTimestamp:fromDevice:
// - didReceiveBatteryLevel:withTimestamp:fromDevice:
// - didUpdateDeviceStatus:forDevice:

struct ibiDataPoint {
    var deviceID: String? = nil;
    var timestamp: Double? = nil;
    var value: Float? = nil;
}

struct gsrDataPoint {
    var deviceID: String? = nil;
    var timestamp: Double? = nil;
    var value: Float? = nil;
}

struct bvpDataPoint {
    var deviceID: String? = nil;
    var timestamp: Double? = nil;
    var value: Float? = nil;
}


struct tempDataPoint {
    var deviceID: String? = nil;
    var timestamp: Double? = nil;
    var value: Float? = nil;
}

struct accDataPoint {
    var deviceID: String? = nil;
    var timestamp: Double? = nil;
    var valx: Int8? = nil;
    var valy: Int8? = nil;
    var valz: Int8? = nil;
}

struct tagDataPoint {
    var deviceID: String? = nil;
    var timestamp: Double? = nil;
}


struct deviceData {
    var serialNumber :String? = nil;
    var ibiVals: [ibiDataPoint] = [];
    var gsrVals: [gsrDataPoint] = [];
    var bvpVals: [bvpDataPoint] = [];
    var tempVals: [tempDataPoint] = [];
    var accVals: [accDataPoint] = [];
    var tagVals: [tagDataPoint] = [];
    var deviceConnectTime: Int? = nil;
    var lastTimeStampPressed: Double? = nil;
}

class ViewController2: UITableViewController {
    
    static let EMPATICA_API_KEY = "81b7f797b7a642008c5f1be3881380f1"
    
    
    private var devices: [EmpaticaDeviceManager] = []
    
    private var deviceDataCollected : [deviceData] = [];
    private var time=0;
    private var timer=Timer();
    
    private var cout=0;
    
    private var initialTime=Date().timeIntervalSince1970;
    
    
    private var allDisconnected : Bool {
        
        return self.devices.reduce(true) { (value, device) -> Bool in
            
            value && device.deviceStatus == kDeviceStatusDisconnected
        }
    }
    
    
    
    @objc func sayhello()
    {
        print(self.cout);
        self.cout=self.cout+1;
        
        
        for (index,device) in self.devices.enumerated(){
            if(device.deviceStatus==kDeviceStatusConnected){
                if(index<self.deviceDataCollected.count){
                    var someDict = [String: Any]();
                    
                    someDict["serialNumber"]=self.deviceDataCollected[index].serialNumber;
                    
                    someDict["deviceConnectTime"]=self.deviceDataCollected[index].deviceConnectTime;
                    
                    
                    
                    let temp=self.deviceDataCollected[index].bvpVals;
                    print(self.deviceDataCollected[index].bvpVals.count)
                    self.deviceDataCollected[index].bvpVals.removeAll();
                    someDict["bvpValsTimeStamp"]=temp.map({$0.timestamp });
                    someDict["bvpVals"]=temp.map({ $0.value });
                    
                    
                    let temp1=self.deviceDataCollected[index].gsrVals;
                    self.deviceDataCollected[index].gsrVals.removeAll();
                    someDict["gsrTimeStamp"]=temp1.map({$0.timestamp });
                    someDict["gsrVals"]=temp1.map({ $0.value });
                    
                    
                    let temp2=self.deviceDataCollected[index].ibiVals;
                    self.deviceDataCollected[index].ibiVals.removeAll();
                    someDict["ibiTimeStamp"]=temp2.map({$0.timestamp });
                    someDict["ibiVals"]=temp2.map({ $0.value });
                    
                    
                    let temp3=self.deviceDataCollected[index].tempVals;
                    self.deviceDataCollected[index].tempVals.removeAll();
                    someDict["tempTimeStamp"]=temp3.map({$0.timestamp });
                    someDict["tempVals"]=temp3.map({ $0.value });
                    
                    let temp4=self.deviceDataCollected[index].accVals;
                    self.deviceDataCollected[index].accVals.removeAll();
                    someDict["accTimeStamp"]=temp4.map({$0.timestamp });
                    someDict["accValsx"]=temp4.map({ $0.valx });
                    someDict["accValsy"]=temp4.map({ $0.valy });
                    someDict["accValsz"]=temp4.map({ $0.valz });
                    
                    
                    someDict["deviceConnectTime"]=self.deviceDataCollected[index].deviceConnectTime;
                    
                    someDict["tagVals"]=self.deviceDataCollected[index].tagVals.map({$0.timestamp });
                    
                    self.deviceDataCollected[index].tagVals.removeAll();
                    
                    
                    guard let url = URL(string: "http://172.31.202.17:1338/physioData") else { return }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    guard let httpBody = try? JSONSerialization.data(withJSONObject: someDict, options: []) else { return }
                    request.httpBody = httpBody
                    
                    let session = URLSession.shared
                    session.dataTask(with: request) { (data, response, error) in
                        if let response = response {
                            //print(response)
                        }
                        
                        if let data = data {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data, options: [])
                                self.deviceDataCollected[index].bvpVals.removeAll();
                                print("success");
                                
                                //print(json)
                            } catch {
                                print("error");
                                print(self.deviceDataCollected[index].bvpVals.count);
                                //print(error)
                            }
                        }
                        
                        }.resume()
                    
                }
                
            }
        }
        
        
        
        
        
    }
    
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.tableView.delegate = self
        
        self.tableView.dataSource = self
        
        //  self.tableView.register(UITableView.self,forCellReuseIdentifier:"device");
        //        tableView.registerClass(UITableViewController.self, forCellReuseIdentifier: cellIdentifier)
        
        
        DispatchQueue.global(qos: .userInteractive).sync {
            self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController2.sayhello), userInfo: nil, repeats: true)
        }
        
        
        //        var helloWorldTimer = timer.scheduledTimer(timeInterval: 1, target: self, selector: Selector("sayHello"), userInfo: nil, repeats: true)
        
        
        
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            
            EmpaticaAPI.authenticate(withAPIKey: ViewController2.EMPATICA_API_KEY) { (status, message) in
                
                if status {
                    
                    // "Authenticated"
                    
                    DispatchQueue.main.async {
                        
                        self.discover()
                        
                        
                    }
                }
            }
        }
    }
    
    private func discover() {
        
        print("hamza")
        print(self.devices.count);
        
        EmpaticaAPI.discoverDevices(with: self)
        
        print(self.devices.count);
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


extension ViewController2: EmpaticaDelegate {
    
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


// - didReceiveIBI:withTimestamp:fromDevice:
// - didReceiveGSR:withTimestamp:fromDevice:
// - didReceiveBVP:withTimestamp:fromDevice:
// - didReceiveTemperature:withTimestamp:fromDevice:
// - didReceiveAccelerationX:y:z:withTimestamp:fromDevice:
// - didReceiveBatteryLevel:withTimestamp:fromDevice:
// - didUpdateDeviceStatus:forDevice:


extension ViewController2: EmpaticaDeviceDelegate {
    
    func didReceiveIBI(_ ibi: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        
        if let index = self.devices.index(of: device) {
            
            var tempData = ibiDataPoint();
            tempData.deviceID=device.serialNumber;
            tempData.timestamp=timestamp;
            tempData.value=ibi;
            
            self.deviceDataCollected[index].ibiVals.append(tempData)
        }
        
        let heartrate = (1/ibi)*60;
        print("\(device.serialNumber!) ibi { \(ibi) }")
        self.updateValue1(device: device, string: "{ \(timestamp) :  \(ibi) secs / \(heartrate) hr}",int: 1);
        
        
    }
    
    func didReceiveGSR(_ gsr: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        if let index = self.devices.index(of: device) {
            
            var tempData = gsrDataPoint();
            tempData.deviceID=device.serialNumber;
            tempData.timestamp=timestamp;
            tempData.value=gsr;
            
            self.deviceDataCollected[index].gsrVals.append(tempData)
        }
        
        self.updateValue1(device: device, string: "\(String(format: "%.2f", abs(gsr))) µS",int: 2)
    }
    
    func didReceiveBVP(_ bvp: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        if let index = self.devices.index(of: device) {
            
            var tempData = bvpDataPoint();
            tempData.deviceID=device.serialNumber;
            tempData.timestamp=timestamp;
            tempData.value=bvp;
            
            self.deviceDataCollected[index].bvpVals.append(tempData)
        }
        
        self.updateValue1(device: device, string: "\(String(format: "%.2f", abs(bvp)))", int: 3)
    }
    
    func didReceiveTemperature(_ temp: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        if let index = self.devices.index(of: device) {
            
            var tempData = tempDataPoint();
            tempData.deviceID=device.serialNumber;
            tempData.timestamp=timestamp;
            tempData.value=temp;
            
            self.deviceDataCollected[index].tempVals.append(tempData)
        }
        
              print("\(device.serialNumber!) TEMP { \(temp) }")
        self.updateValue1(device: device, string: "{ \(temp) }", int: 4);
    }
    
    
    func didReceiveAccelerationX(_ x: Int8, y: Int8, z: Int8, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        
        
        if let index = self.devices.index(of: device) {
            
            var tempData = accDataPoint();
            tempData.deviceID=device.serialNumber;
            tempData.valx=x;
            tempData.valy=y;
            tempData.valz=z;
            tempData.timestamp=timestamp;
            //print(self.deviceDataCollected[index].accVals.count);
            self.deviceDataCollected[index].accVals.append(tempData)
        }
        
        self.updateValue1(device: device, string: "{x: \(x), y: \(y), z: \(z)}" ,int: 5);
        //        print("\(device.serialNumber!) ACC > {x: \(x), y: \(y), z: \(z)}")
    }
    
    func didReceiveBatteryLevel(_ battery: Float, withTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        self.updateValue1(device: device, string: "{\(battery)}" ,int: 6);
        
        
        print("\(device.serialNumber!) {\(battery)}")
        
        
    }
    
    
    
    
    func didReceiveTag(atTimestamp timestamp: Double, fromDevice device: EmpaticaDeviceManager!) {
        
        print("\(device.serialNumber!) TAG received { \(timestamp) }")
        if let index = self.devices.index(of: device) {
            
            var tempData = tagDataPoint();
            tempData.deviceID=device.serialNumber;
            tempData.timestamp=timestamp;
            self.deviceDataCollected[index].tagVals.append(tempData)
        }
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

extension ViewController2 {
    
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        EmpaticaAPI.cancelDiscovery()
        
        print(indexPath.section);
        
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

extension ViewController2 {
    
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
        
        // - didReceiveIBI:withTimestamp:fromDevice:
        // - didReceiveGSR:withTimestamp:fromDevice:
        // - didReceiveBVP:withTimestamp:fromDevice:
        // - didReceiveTemperature:withTimestamp:fromDevice:
        // - didReceiveAccelerationX:y:z:withTimestamp:fromDevice:
        // - didReceiveBatteryLevel:withTimestamp:fromDevice:
        // - didUpdateDeviceStatus:forDevice:
        
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




