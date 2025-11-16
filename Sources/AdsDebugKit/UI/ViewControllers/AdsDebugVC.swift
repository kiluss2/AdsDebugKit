//
//  AdsDebugVC.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit

final class AdsDebugVC: UIViewController {
    private let pageVC = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
    private let segmentedControl = UISegmentedControl(items: ["Ad States", "Ad Events", "Adjust", "Settings"])
    
    private let statesVC = AdsDebugStatesVC()
    private let eventsVC = AdsDebugEventsVC()
    private let adjustLogsVC = AdsDebugAdjustLogsVC()
    private let settingsVC = AdsDebugSettingsVC()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Ads Debug Console"
        view.backgroundColor = .systemBackground
        
        // Setup segmented control
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        // Wrap segmentedControl in a container UIView to shift it down by 8px
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(segmentedControl)
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        navigationItem.titleView = container
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .done,
            target: self,
            action: #selector(closeTap)
        )
        
        // Setup page view controller
        pageVC.dataSource = self
        pageVC.delegate = self
        pageVC.setViewControllers([statesVC], direction: .forward, animated: false)
        
        addChild(pageVC)
        view.addSubview(pageVC.view)
        pageVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pageVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        pageVC.didMove(toParent: self)
    }
    
    @objc private func segmentChanged() {
        let index = segmentedControl.selectedSegmentIndex
        let vc: UIViewController
        
        switch index {
        case 0:
            vc = statesVC
        case 1:
            vc = eventsVC
        case 2:
            vc = adjustLogsVC
        case 3:
            vc = settingsVC
        default:
            return
        }
        
        // Determine direction based on current page
        let currentIndex: Int
        if pageVC.viewControllers?.first === statesVC {
            currentIndex = 0
        } else if pageVC.viewControllers?.first === eventsVC {
            currentIndex = 1
        } else if pageVC.viewControllers?.first === adjustLogsVC {
            currentIndex = 2
        } else if pageVC.viewControllers?.first === settingsVC {
            currentIndex = 3
        } else {
            currentIndex = 0
        }
        
        let direction: UIPageViewController.NavigationDirection = index > currentIndex ? .forward : .reverse
        pageVC.setViewControllers([vc], direction: direction, animated: true)
    }
    
    @objc private func closeTap() {
        // Dismiss and cleanup window
        AdsDebugWindowManager.shared.hide()
    }
}

extension AdsDebugVC: UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if viewController === statesVC {
            return nil
        } else if viewController === eventsVC {
            return statesVC
        } else if viewController === adjustLogsVC {
            return eventsVC
        } else {
            return adjustLogsVC
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if viewController === statesVC {
            return eventsVC
        } else if viewController === eventsVC {
            return adjustLogsVC
        } else if viewController === adjustLogsVC {
            return settingsVC
        } else {
            return nil
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let current = pageViewController.viewControllers?.first else { return }
        
        if current === statesVC {
            segmentedControl.selectedSegmentIndex = 0
        } else if current === eventsVC {
            segmentedControl.selectedSegmentIndex = 1
        } else if current === adjustLogsVC {
            segmentedControl.selectedSegmentIndex = 2
        } else if current === settingsVC {
            segmentedControl.selectedSegmentIndex = 3
        }
    }
}
