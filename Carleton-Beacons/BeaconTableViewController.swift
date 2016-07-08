//
//  BeaconTableViewController.swift
//  Carleton-Beacons
//
//  Created by bilskys on 7/5/16.
//  Copyright © 2016 Estimote, Inc. All rights reserved.
//

import UIKit
import Foundation

class BeaconTableViewController: UITableViewController, ESTBeaconManagerDelegate {
    
    //@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    var activityIndicator = UIActivityIndicatorView()
    
    let beaconManager = ESTBeaconManager()
    
    let beaconRegion = CLBeaconRegion(proximityUUID: NSUUID(UUIDString: "70A27C24-0DD0-4C4F-99B2-3F642A998F27")!, identifier: "test")
    
    var beaconInfo: [String: BeaconInfo] = Dictionary()
    
    var beaconInfoByTableOrder: [BeaconInfo] = Array()
    
    var beaconInfoHasBeenSaved = false
    
    var beaconInfoHasBeenLoaded = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.beaconManager.delegate = self
        
        self.beaconManager.requestWhenInUseAuthorization()
        
        self.beaconInfo = Dictionary()
        
        getBeaconInfoJSON() { (dataHasBeenLoaded) -> Void in
            if dataHasBeenLoaded {
                // print("Stopping activity indicator")
                // self.activityIndicator.stopAnimating()
            }
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        // start ranging for beacons when app is launched
        super.viewWillAppear(animated)
        
        self.beaconManager.startRangingBeaconsInRegion(self.beaconRegion)
    }
    
    override func viewDidDisappear(animated: Bool) {
        // stop ranging for beacons when app is quit
        super.viewDidDisappear(animated)
        
        self.beaconManager.stopRangingBeaconsInRegion(self.beaconRegion)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func showActivityIndicator() {
        self.activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 290, y: 290, width: 40, height: 40))
        self.activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.Gray
        self.activityIndicator.hidesWhenStopped = true
        self.view.addSubview(self.activityIndicator)
        self.activityIndicator.startAnimating()
    }
       
    func getBeaconInfoJSON(completion: (dataHasBeenLoaded: Bool) -> Void) {
        // Download JSON file containing beacon info
        var json: [String: AnyObject] = Dictionary()
        DataManager.getBeaconInfoFromWebWithSuccess() { (jsonData) -> Void in
            do {
                json = try NSJSONSerialization.JSONObjectWithData(jsonData, options: .AllowFragments) as! [String : AnyObject]
                self.parseJSONInfo(json)
                self.loadBeaconInfo()
                completion(dataHasBeenLoaded: true)
            } catch {
                print(error)
                completion(dataHasBeenLoaded: false)
            }
        }
    }
    
    func parseJSONInfo(json: [String: AnyObject]) {
        // Parse beacon info from JSON file and save parsed data
        var beaconInfo: [String: BeaconInfo] = Dictionary()
        
        guard let metadata = json["metadata"] as? [String: AnyObject] else {
                print("Error serializing JSON metadata")
                return
        }
        let newLastUpdated = metadata["last-updated"]
        //let oldLastUpdated =
        print("Beacon info last updated at \(newLastUpdated)")
        
        guard let data = json["data"] as? [String: [String: AnyObject]] else {
                print("Error serializing JSON data")
                return
        }
        
        guard let allBeacons = data["beacons"] as? [String: [String: String]] else {
                print("Error serializing JSON data")
                return
        }
        
        for beacon in allBeacons {
            let beaconKey = beacon.0
            let beaconInfoDict = beacon.1
            
            let title = beaconInfoDict["title"]
            let subtitle = beaconInfoDict["subtitle"]
            let description = beaconInfoDict["description"]
            let image = beaconInfoDict["image"]
            
            let beaconInfoObj = BeaconInfo(title: title, subtitle: subtitle, description: description, image: image)
            beaconInfo[beaconKey] = beaconInfoObj
        }
        // Persist dictionary of BeaconInfo objects
        let beaconInfoSaved = NSKeyedArchiver.archiveRootObject(beaconInfo, toFile: BeaconInfo.ArchiveURL.path!)
        print("Beacon info saved!")
        print("Beacon info:")
        print(beaconInfo)
        self.beaconInfoHasBeenSaved = true
        
        if !beaconInfoSaved {
            print("Error saving beacon info dictionary")
        }
    }
    
    func loadBeaconInfo() {
        self.beaconInfo = NSKeyedUnarchiver.unarchiveObjectWithFile(BeaconInfo.ArchiveURL.path!) as! [String: BeaconInfo]
        self.beaconInfoHasBeenLoaded = true
        print("Beacon info loaded!")
    }
    
    func getBeaconInfoForBeacon(beacon: CLBeacon) -> BeaconInfo? {
        let beaconKey = "\(beacon.major):\(beacon.minor)"
        let beaconInfoObj = self.beaconInfo[beaconKey] as BeaconInfo!
        return beaconInfoObj
    }
    
    func beaconManager(manager: AnyObject, didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion) {
        var beaconInfoByTableOrder: [BeaconInfo] = Array()
        
        // Make sure that we have at least as many beacon info objects as beacons in range
        guard self.beaconInfo.count >= beacons.count else {
                print("No beacon info yet")
                return
            }
        
        for beacon in beacons {
            let beaconInfoObj = getBeaconInfoForBeacon(beacon)
            beaconInfoByTableOrder.append(beaconInfoObj!)
        }
        
        self.beaconInfoByTableOrder = beaconInfoByTableOrder
        
        self.tableView.reloadData()
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return beaconInfoByTableOrder.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Basic")!
        
        cell.textLabel?.text = beaconInfoByTableOrder[indexPath.row].title
        cell.textLabel?.contentScaleFactor
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        
        cell.detailTextLabel?.text = beaconInfoByTableOrder[indexPath.row].subtitle
        cell.detailTextLabel?.minimumScaleFactor = 0
        cell.detailTextLabel?.adjustsFontSizeToFitWidth = true
        
        let image = UIImage(named: "beacon")!
        cell.imageView?.image = image
        
        return cell
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
//        if segue.identifier == "BeaconSegue" {
//            print("Correct segue")
        let selectedRow = tableView.indexPathForSelectedRow?.row
        
        if let dest = segue.destinationViewController as? BeaconViewController {
            dest.beaconInfoObj = beaconInfoByTableOrder[selectedRow!]
            //}
        }
    }
}