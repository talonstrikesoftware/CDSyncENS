//
//  MainTVCell.swift
//  CDSync
//
//  Copyright (c) 2015 Talon Strike Software. All rights reserved.
//

import UIKit

class MainTVCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func configureCell(entity: Entity) {
        nameLabel.text = entity.name
        descLabel.text = entity.desctext
    }

}
