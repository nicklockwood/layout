//
//  PagesViewController.swift
//  SampleApp
//
//  Created by Nick Lockwood on 13/05/2017.
//  Copyright © 2017 Nick Lockwood. All rights reserved.
//

import UIKit

class PagesViewController: UIViewController, UIScrollViewDelegate {

    var scrollView: UIScrollView!
    var pageControl: UIPageControl!

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === self.scrollView {
            pageControl.currentPage = Int(round(scrollView.contentOffset.x / scrollView.frame.width))
        }
    }
}
