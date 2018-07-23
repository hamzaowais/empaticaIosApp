//
//  View0ViewController.swift
//  E4tester
//
//  Created by UT HTI Lab on 7/21/18.
//  Copyright © 2018 Felipe Castro. All rights reserved.
//

import UIKit

class View0ViewController: UIViewController {

    @IBOutlet weak var hostAddress: UITextField!
    
   
    @IBAction func continueAction(_ sender: Any) {
        if(hostAddress.text != ""){
            //print("shit")
           performSegue(withIdentifier: "segue", sender: self)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var secondController=segue.destination as! ViewController
        secondController.hostaddress = hostAddress.text!;
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
