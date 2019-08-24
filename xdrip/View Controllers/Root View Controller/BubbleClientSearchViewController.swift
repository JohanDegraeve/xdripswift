//
//  BubbleClientSearchViewController.swift
//
//  Created by yan on 2019/7/24.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import UIKit
import CoreBluetooth

class BubbleClientSearchViewController: UITableViewController {
    var list = [BluetoothPeripheral]() {
        didSet {
            tableView.reloadData()
        }
    }
    var cgmTransmitter: CGMTransmitter?
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        let button = UIBarButtonItem.init(title: NSLocalizedString("Scan", comment: "scan bubble"), style: .done, target: self, action: #selector(scanAction))
        self.navigationItem.setRightBarButton(button, animated: false)
        
        let back = UIBarButtonItem.init(title: NSLocalizedString("Back", comment: "back"), style: .done, target: self, action: #selector(backAction))
        self.navigationItem.setLeftBarButton(back, animated: false)
    }
    
    @objc func backAction() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func scanAction() {
        let _ = cgmTransmitter?.startScanning()
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return list.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = list[indexPath.row].mac
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let peripheral = list[indexPath.row].peripheral {
            cgmTransmitter?.connect(to: peripheral)
        }
        self.backAction()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
