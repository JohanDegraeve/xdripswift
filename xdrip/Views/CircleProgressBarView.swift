//
//  CircleProgressBarView.swift
//  xdrip
//
//  Created by Олег Стригунов on 15.12.2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import UIKit

class CircleProgressBarView: UIView, CAAnimationDelegate {
	
	// MARK: - Properties
	private let trackLayer: CAShapeLayer = {
		let layer = CAShapeLayer()
		layer.strokeColor = UIColor.systemGray3.cgColor
		layer.lineWidth = 10
		layer.strokeEnd = 1.0
		layer.lineCap = .butt
		layer.fillColor = UIColor.clear.cgColor
		return layer
	}()
	
	private let redLayer: CAShapeLayer = {
		let layer = CAShapeLayer()
		layer.strokeColor = UIColor.systemRed.cgColor
		layer.lineWidth = 10
		layer.strokeEnd = 1.0
		layer.lineCap = .butt
		layer.fillColor = UIColor.clear.cgColor
		layer.isHidden = true
		return layer
	}()
	
	private let greenLayer: CAShapeLayer = {
		let layer = CAShapeLayer()
		layer.strokeColor = UIColor.systemGreen.cgColor
		layer.lineWidth = 10
		layer.strokeEnd = 0
		layer.lineCap = .butt
		layer.fillColor = UIColor.clear.cgColor
		return layer
	}()
	
	private let yellowLayer: CAShapeLayer = {
		let layer = CAShapeLayer()
		layer.strokeColor = UIColor.systemYellow.cgColor
		layer.lineWidth = 10
		layer.strokeEnd = 0
		layer.lineCap = .butt
		layer.fillColor = UIColor.clear.cgColor
		return layer
	}()
	
	private let timerLabel: UILabel = {
		let label = UILabel()
		label.textAlignment = .center
		label.font = UIFont.systemFont(ofSize: 10, weight: .regular)
		label.textColor = .white
		label.text = "00:00"
		return label
	}()
	
	private var centerPoint: CGPoint {
		CGPoint(x: bounds.midX, y: bounds.midY)
	}
	
	private var radius: CGFloat {
		min(bounds.width, bounds.height) / 2 - trackLayer.lineWidth / 2
	}
	
	private lazy var trackPath: UIBezierPath = {
		UIBezierPath(
			arcCenter: centerPoint,
			radius: radius,
			startAngle: -CGFloat.pi / 2,
			endAngle: 3 * CGFloat.pi / 2,
			clockwise: true
		)
	}()
	
	private lazy var redPath: UIBezierPath = {
		UIBezierPath(
			arcCenter: centerPoint,
			radius: radius,
			startAngle: -CGFloat.pi / 2,
			endAngle: 3 * CGFloat.pi / 2,
			clockwise: true
		)
	}()
	
	private lazy var greenPath: UIBezierPath = {
		UIBezierPath(
			arcCenter: centerPoint,
			radius: radius,
			startAngle: -CGFloat.pi / 2,
			endAngle: 3 * CGFloat.pi / 2,
			clockwise: true
		)
	}()
	
	private lazy var yellowPath: UIBezierPath = {
		UIBezierPath(
			arcCenter: centerPoint,
			radius: radius,
			startAngle: -CGFloat.pi / 2,
			endAngle: 3 * CGFloat.pi / 2,
			clockwise: true
		)
	}()
	
	private var completedAnimations = 0
	private var totalAnimations = 0
	private var timer: Timer?
	private var elapsedTime: TimeInterval = 0
	
	private var greenDuration: CFTimeInterval = 0
	private var yellowDuration: CFTimeInterval = 0
	
	// MARK: - Init
	override init(frame: CGRect) {
		super.init(frame: frame)
		setupView()
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupView()
	}
	
	// MARK: - View Setup
	private func setupView() {
		yellowLayer.path = yellowPath.cgPath
		greenLayer.path = greenPath.cgPath
		redLayer.path = redPath.cgPath
		trackLayer.path = trackPath.cgPath
		
		layer.addSublayer(trackLayer)
		layer.addSublayer(yellowLayer)
		layer.addSublayer(greenLayer)
		layer.addSublayer(redLayer)
		
		addSubview(timerLabel)
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		updatePaths()
		timerLabel.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 20)
		timerLabel.center = centerPoint
	}
	
	private func updatePaths() {
		yellowLayer.path = yellowPath.cgPath
		greenLayer.path = greenPath.cgPath
		redLayer.path = redPath.cgPath
	}
	
	// MARK: - Set Progress
	func setProgress(greenDuration: CFTimeInterval, yellowDuration: CFTimeInterval) {
		self.greenDuration = greenDuration
		self.yellowDuration = yellowDuration
		
		totalAnimations = 2
		completedAnimations = 0
		
		elapsedTime = 0
		startTimer()
		
		let duration = greenDuration + yellowDuration
		let greenValue = CGFloat(greenDuration) / CGFloat(duration)
		
		animateLayer(layer: yellowLayer, toValue: 1.0, duration: duration)
		animateLayer(layer: greenLayer, toValue: greenValue, duration: greenDuration)
	}
	
	private func animateLayer(layer: CAShapeLayer, toValue: CGFloat, duration: CFTimeInterval) {
		let animation = CABasicAnimation(keyPath: "strokeEnd")
		animation.toValue = toValue
		animation.duration = duration
		animation.fillMode = .forwards
		animation.isRemovedOnCompletion = false
		animation.delegate = self
		layer.add(animation, forKey: nil)
	}
	
	// MARK: - Timer
	private func startTimer() {
		timer?.invalidate()
		timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
	}
	
	@objc private func updateTimer() {
		elapsedTime += 1
		let minutes = Int(elapsedTime) / 60
		let seconds = Int(elapsedTime) % 60
		timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
	}

	func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
		if flag {
			completedAnimations += 1
			if completedAnimations == totalAnimations {
				redLayer.isHidden = false
			}
		}
	}
	
	func resetProgress() {
		redLayer.isHidden = true
		yellowLayer.removeAllAnimations()
		greenLayer.removeAllAnimations()
		yellowLayer.strokeEnd = 0
		greenLayer.strokeEnd = 0
		
		timer?.invalidate()
		timerLabel.text = "00:00"
		timer = nil
	}
	
	// MARK: - Restart Progress
	func restartProgress() {
		resetProgress()
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			self.setProgress(greenDuration: self.greenDuration, yellowDuration: self.yellowDuration)
		}
	}
}


