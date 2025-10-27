import Cocoa
import QuartzCore

// MARK: - Timestamped Note Entry
struct TimestampedNoteEntry: Codable {
    let id: UUID
    let content: String
    let timestamp: Date
    
    init(content: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Task Detail View
protocol TaskDetailViewDelegate: AnyObject {
    func closeTaskDetail(for taskId: UUID)
    func taskDetailView(_ view: TaskDetailView, didTogglePin isPinned: Bool)
}

class TaskDetailView: NSView {
    private var task: Task
    private var orbColor: NSColor
    private weak var delegate: TaskDetailViewDelegate?

    // Text size scale factor
    private var textScale: CGFloat {
        return TextSizePreference.scaleFactor
    }

    private let backdropView = NSVisualEffectView()
    private let contentStack = NSStackView()
    private let chromeLayer = CAGradientLayer()
    private let dragStripView = TaskDetailDragStripView()

    private let titleField = NSTextField()
    private let closeButton = NSButton()
    private let pinButton = NSButton()
    private let deleteButton = NSButton()
    
    private let metaRow = NSStackView()
    private let statusControl = NSSegmentedControl(labels: ["Outstanding", "In Progress", "Complete"], trackingMode: .selectOne, target: nil, action: nil)
    private let dueButton = NSButton()
    private let clearDueButton = NSButton()
    private let priorityControl = NSSegmentedControl(labels: ["Low", "Med", "High"], trackingMode: .selectOne, target: nil, action: nil)
    
    private let notesLabel = NSTextField(labelWithString: "Notes")
    private let notesScrollView = NSScrollView()
    private let notesStackView = NSStackView()
    private let notesInputField = NSTextField()
    private let notesInputButton = NSButton()
    private var timestampedNotes: [TimestampedNoteEntry] = []
    
    private let actionRow = NSStackView()
    private let copyTitleButton = NSButton()
    private let copyNotesButton = NSButton()
    
    private let metadataLabel = NSTextField(labelWithString: "")
    
    private lazy var datePopover: NSPopover = createDatePopover()
    private let datePicker = NSDatePicker()
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private lazy var dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter
    }()
    
    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    private let priorityValues = [1, 3, 5]
    private let priorityLabels = ["Low", "Medium", "High"]
    
    private var isClosing = false
    private var isPinned = false
    
    init(task: Task, orbColor: NSColor) {
        self.task = task
        self.orbColor = orbColor
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 380))
        translatesAutoresizingMaskIntoConstraints = false
        setupView()
        updateUI()
    }
    
    func setDelegate(_ delegate: TaskDetailViewDelegate?) {
        self.delegate = delegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        datePopover.close()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 24
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.2).cgColor
        layer?.shadowOpacity = 1.0
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.shadowRadius = 12

        configureBackdrop()
        configureDragStrip()
        configureContentStack()
        configureTitle()
        configureNotesSection()
        configureMetaRow()
        chromeLayer.type = .axial
        chromeLayer.opacity = 0.45
        chromeLayer.cornerRadius = 24
        chromeLayer.masksToBounds = true
        backdropView.layer?.insertSublayer(chromeLayer, at: 0)

        updateChromePalette()
        updateDragStripAppearance()
    }
    
    override func layout() {
        super.layout()
        chromeLayer.frame = backdropView.bounds
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let detailWindow = window as? TaskDetailWindow {
            isPinned = detailWindow.isPinned
            updatePinButtonAppearance()

            // Smooth fade-in and scale animation
            if window != nil {
                animateAppearance()
            }
        }
    }

    private func animateAppearance() {
        // Start invisible and slightly scaled down
        layer?.opacity = 0.0
        layer?.transform = CATransform3DMakeScale(0.94, 0.94, 1.0)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0) // Smooth ease-out
            context.allowsImplicitAnimation = true

            // Fade in and scale to normal
            self.layer?.opacity = 1.0
            self.layer?.transform = CATransform3DIdentity
        }, completionHandler: nil)
    }
    
    private func configureBackdrop() {
        backdropView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.state = .active
        backdropView.blendingMode = .withinWindow
        backdropView.material = .hudWindow
        backdropView.wantsLayer = true
        backdropView.layer?.cornerRadius = 24
        backdropView.layer?.masksToBounds = true
        addSubview(backdropView)
        
        NSLayoutConstraint.activate([
            backdropView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdropView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdropView.topAnchor.constraint(equalTo: topAnchor),
            backdropView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func configureDragStrip() {
        dragStripView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dragStripView)
        
        NSLayoutConstraint.activate([
            dragStripView.topAnchor.constraint(equalTo: topAnchor),
            dragStripView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dragStripView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dragStripView.heightAnchor.constraint(equalToConstant: TaskRowMetrics.dragGripHeight)
        ])

        configureChromeButtons()
    }
    
    private func configureContentStack() {
        contentStack.orientation = .vertical
        contentStack.spacing = 20
        contentStack.alignment = .leading
        contentStack.edgeInsets = NSEdgeInsets(top: 120, left: 24, bottom: 24, right: 24) // Space for drag strip + buttons + title
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        backdropView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: backdropView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: backdropView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: backdropView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: backdropView.bottomAnchor)
        ])
    }
    
    private func configureTitle() {
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.isEditable = true
        titleField.isBordered = false
        titleField.drawsBackground = false
        titleField.focusRingType = .none
        titleField.font = NSFont.systemFont(ofSize: 19 * textScale, weight: .semibold)
        titleField.textColor = NSColor(calibratedWhite: 0.08, alpha: 1.0) // Higher contrast
        titleField.alignment = .center
        titleField.lineBreakMode = .byTruncatingTail
        titleField.stringValue = task.title
        titleField.delegate = self
        titleField.target = self
        titleField.action = #selector(handleTitleEditingEnd)

        backdropView.addSubview(titleField)

        // Position title below the buttons, centered
        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: backdropView.leadingAnchor, constant: 32),
            titleField.trailingAnchor.constraint(equalTo: backdropView.trailingAnchor, constant: -32),
            titleField.topAnchor.constraint(equalTo: dragStripView.topAnchor, constant: 72),
            titleField.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    private func configureChromeButtons() {
        let buttons = [closeButton, pinButton, deleteButton]
        let buttonSize: CGFloat = 28
        let horizontalInset: CGFloat = 20
        let buttonSpacing: CGFloat = 12

        for button in buttons {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.isBordered = false
            button.bezelStyle = .shadowlessSquare
            button.imagePosition = .imageOnly
            button.focusRingType = .none
            button.wantsLayer = true
            button.layer?.backgroundColor = NSColor.clear.cgColor // No background bubble
            button.layer?.masksToBounds = false
            button.imageScaling = .scaleProportionallyDown
            button.setContentHuggingPriority(.required, for: .horizontal)
            dragStripView.addSubview(button)
        }

        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close task")
        closeButton.contentTintColor = NSColor(calibratedWhite: 0.4, alpha: 0.8)
        closeButton.target = self
        closeButton.action = #selector(handleCloseTapped)
        closeButton.toolTip = "Close"

        pinButton.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin task card")
        pinButton.contentTintColor = NSColor(calibratedWhite: 0.4, alpha: 0.8)
        pinButton.target = self
        pinButton.action = #selector(handlePinTapped)
        pinButton.toolTip = "Pin"

        deleteButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete task")
        deleteButton.contentTintColor = NSColor(calibratedWhite: 0.4, alpha: 0.8)
        deleteButton.target = self
        deleteButton.action = #selector(handleDeleteTapped)
        deleteButton.toolTip = "Delete"

        // Icon buttons below drag handle
        // Layout: Close (left) ... Pin, Delete (right)
        let iconY: CGFloat = 28 // Below the drag handle

        NSLayoutConstraint.activate([
            // Close button on left
            closeButton.leadingAnchor.constraint(equalTo: dragStripView.leadingAnchor, constant: horizontalInset),
            closeButton.topAnchor.constraint(equalTo: dragStripView.topAnchor, constant: iconY),
            closeButton.widthAnchor.constraint(equalToConstant: buttonSize),
            closeButton.heightAnchor.constraint(equalToConstant: buttonSize),

            // Delete button on right
            deleteButton.trailingAnchor.constraint(equalTo: dragStripView.trailingAnchor, constant: -horizontalInset),
            deleteButton.topAnchor.constraint(equalTo: dragStripView.topAnchor, constant: iconY),
            deleteButton.widthAnchor.constraint(equalToConstant: buttonSize),
            deleteButton.heightAnchor.constraint(equalToConstant: buttonSize),

            // Pin button next to delete
            pinButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -buttonSpacing),
            pinButton.topAnchor.constraint(equalTo: dragStripView.topAnchor, constant: iconY),
            pinButton.widthAnchor.constraint(equalToConstant: buttonSize),
            pinButton.heightAnchor.constraint(equalToConstant: buttonSize)
        ])

        updatePinButtonAppearance()
    }

    @objc private func handleDeleteTapped() {
        // TODO: Implement delete functionality
        print("Delete tapped")
    }
    
    private func configureMetaRow() {
        metaRow.orientation = .horizontal
        metaRow.alignment = .top // Align at top for label consistency
        metaRow.spacing = 24 // Slightly more space between columns
        metaRow.distribution = .fillEqually // Equal width columns for better visual balance
        metaRow.translatesAutoresizingMaskIntoConstraints = false
        metaRow.edgeInsets = NSEdgeInsets(top: 0, left: 30, bottom: 0, right: 30)
        contentStack.addArrangedSubview(metaRow)
        // Let the meta row use the contentStack's natural padding
        contentStack.setCustomSpacing(0, after: metaRow)
        
        // Force the meta row to stick to the bottom with a bit more space
        NSLayoutConstraint.activate([
            metaRow.bottomAnchor.constraint(equalTo: contentStack.bottomAnchor, constant: -15)
        ])
        
        statusControl.segmentStyle = .rounded
        statusControl.target = self
        statusControl.action = #selector(handleStatusChanged)
        statusControl.translatesAutoresizingMaskIntoConstraints = false
        statusControl.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        statusControl.setContentCompressionResistancePriority(.required, for: .horizontal)
        statusControl.heightAnchor.constraint(equalToConstant: 28).isActive = true

        // Enhanced styling for status control
        statusControl.wantsLayer = true
        statusControl.layer?.masksToBounds = true
        statusControl.layer?.cornerRadius = 8
        statusControl.layer?.borderColor = NSColor(calibratedWhite: 0.3, alpha: 1.0).cgColor
        statusControl.layer?.borderWidth = 1.5
        
        dueButton.title = "Set due date"
        dueButton.isBordered = false
        dueButton.wantsLayer = true
        dueButton.layer?.cornerRadius = 8 // Match segmented control corners
        dueButton.target = self
        dueButton.action = #selector(handleDueTapped)
        dueButton.font = NSFont.systemFont(ofSize: 13 * textScale, weight: .semibold) // Slightly smaller to fit
        dueButton.contentTintColor = .white
        dueButton.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Set due date")
        dueButton.imagePosition = .imageLeading
        dueButton.heightAnchor.constraint(equalToConstant: 28).isActive = true // Match segmented controls
        dueButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        dueButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        // Add internal padding
        if let cell = dueButton.cell as? NSButtonCell {
            cell.imagePosition = .imageLeading
            cell.imageScaling = .scaleProportionallyDown
        }
        // Add subtle shadow
        dueButton.layer?.shadowColor = orbColor.withAlphaComponent(0.3).cgColor
        dueButton.layer?.shadowOpacity = 1.0
        dueButton.layer?.shadowOffset = CGSize(width: 0, height: 1)
        dueButton.layer?.shadowRadius = 3
        
        clearDueButton.isBordered = false
        clearDueButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear due date")
        clearDueButton.contentTintColor = NSColor.white.withAlphaComponent(0.6)
        clearDueButton.target = self
        clearDueButton.action = #selector(handleClearDue)
        clearDueButton.toolTip = "Clear due date"
        clearDueButton.translatesAutoresizingMaskIntoConstraints = false
        clearDueButton.widthAnchor.constraint(equalToConstant: 20).isActive = true
        clearDueButton.heightAnchor.constraint(equalToConstant: 20).isActive = true
        clearDueButton.setContentHuggingPriority(.required, for: .horizontal)
        
        priorityControl.segmentStyle = .rounded
        priorityControl.target = self
        priorityControl.action = #selector(handlePriorityChanged)
        priorityControl.translatesAutoresizingMaskIntoConstraints = false
        priorityControl.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        priorityControl.setContentCompressionResistancePriority(.required, for: .horizontal)
        priorityControl.heightAnchor.constraint(equalToConstant: 28).isActive = true // Reduced to fit segments

        // Enhanced styling for priority control
        priorityControl.wantsLayer = true
        priorityControl.layer?.masksToBounds = true // Clip to bounds
        priorityControl.layer?.cornerRadius = 8
        priorityControl.layer?.borderColor = NSColor(calibratedWhite: 0.3, alpha: 1.0).cgColor // Higher contrast border
        priorityControl.layer?.borderWidth = 1.5
        
        let statusColumn = makeMetaColumn(title: "STATUS", content: statusControl)
        let dueHorizontal = NSStackView(views: [dueButton, clearDueButton])
        dueHorizontal.spacing = 10
        dueHorizontal.alignment = .centerY
        let dueColumn = makeMetaColumn(title: "DUE", content: dueHorizontal)
        let priorityColumn = makeMetaColumn(title: "PRIORITY", content: priorityControl)
        
        metaRow.addArrangedSubview(statusColumn)
        metaRow.addArrangedSubview(dueColumn)
        metaRow.addArrangedSubview(priorityColumn)
    }
    
    private func configureNotesSection() {
        notesLabel.stringValue = "NOTES & CONTEXT"
        notesLabel.font = NSFont.systemFont(ofSize: 11 * textScale, weight: .bold)
        notesLabel.textColor = NSColor(calibratedWhite: 0.15, alpha: 1.0) // Higher contrast
        notesLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(notesLabel)
        contentStack.setCustomSpacing(16, after: notesLabel) // Tighter spacing to section

        // Configure notes stack view for timestamped entries
        notesStackView.orientation = .vertical
        notesStackView.alignment = .leading
        notesStackView.spacing = 10
        notesStackView.translatesAutoresizingMaskIntoConstraints = false
        notesStackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal) // Allow shrinking
        notesStackView.setHuggingPriority(.defaultLow, for: .horizontal) // Fill available width

        // Configure scroll view with enhanced styling
        notesScrollView.translatesAutoresizingMaskIntoConstraints = false
        notesScrollView.borderType = .noBorder
        notesScrollView.drawsBackground = false
        notesScrollView.hasVerticalScroller = true
        notesScrollView.hasHorizontalScroller = false // Disable horizontal scrolling
        notesScrollView.autohidesScrollers = true
        notesScrollView.wantsLayer = true
        notesScrollView.layer?.cornerRadius = 12
        notesScrollView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        notesScrollView.layer?.borderColor = NSColor.clear.cgColor
        notesScrollView.layer?.borderWidth = 0
        notesScrollView.layer?.masksToBounds = true
        notesScrollView.heightAnchor.constraint(equalToConstant: 130).isActive = true
        
        notesScrollView.documentView = notesStackView
        
        // Configure input field with enhanced styling
        notesInputField.translatesAutoresizingMaskIntoConstraints = false
        notesInputField.isBordered = true
        notesInputField.isBezeled = true
        notesInputField.bezelStyle = .roundedBezel
        notesInputField.font = NSFont.systemFont(ofSize: 13 * textScale, weight: .regular)
        notesInputField.textColor = NSColor(calibratedWhite: 0.05, alpha: 1.0) // Higher contrast
        notesInputField.backgroundColor = NSColor.white.withAlphaComponent(0.15)
        notesInputField.placeholderString = "Add a note... (press Enter to submit)"
        notesInputField.target = self
        notesInputField.action = #selector(handleNotesInput)

        // Enhanced add button with orb color
        notesInputButton.translatesAutoresizingMaskIntoConstraints = false
        notesInputButton.title = "Add"
        notesInputButton.bezelStyle = .inline
        notesInputButton.isBordered = false
        notesInputButton.font = NSFont.systemFont(ofSize: 13 * textScale, weight: .semibold)
        notesInputButton.wantsLayer = true
        notesInputButton.layer?.cornerRadius = 10
        notesInputButton.layer?.backgroundColor = orbColor.withAlphaComponent(0.2).cgColor // Lighter background
        notesInputButton.layer?.shadowColor = orbColor.withAlphaComponent(0.3).cgColor
        notesInputButton.layer?.shadowOpacity = 0.3
        notesInputButton.layer?.shadowOffset = CGSize(width: 0, height: 1)
        notesInputButton.layer?.shadowRadius = 2
        notesInputButton.contentTintColor = NSColor.systemBlue.withAlphaComponent(0.9) // Dark blue text
        notesInputButton.target = self
        notesInputButton.action = #selector(handleAddNote)

        // Add internal padding
        if let cell = notesInputButton.cell as? NSButtonCell {
            cell.imagePosition = .noImage
        }
        
        let inputRow = NSStackView()
        inputRow.orientation = .horizontal
        inputRow.spacing = 8
        inputRow.alignment = .centerY
        inputRow.distribution = .fill
        inputRow.translatesAutoresizingMaskIntoConstraints = false
        inputRow.addArrangedSubview(notesInputField)
        inputRow.addArrangedSubview(notesInputButton)

        notesInputButton.widthAnchor.constraint(equalToConstant: 70).isActive = true // More width for padding
        notesInputButton.heightAnchor.constraint(equalToConstant: 32).isActive = true // Explicit height
        notesInputField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        contentStack.addArrangedSubview(notesScrollView)
        contentStack.addArrangedSubview(inputRow)
        
        // Load existing notes from task.details
        loadExistingNotes()
        
        contentStack.setCustomSpacing(20, after: inputRow)
    }
    
    private func configureActionRow() {
        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.spacing = 18
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        
        copyTitleButton.title = "Copy Title"
        copyTitleButton.bezelStyle = .inline
        copyTitleButton.isBordered = false
        copyTitleButton.target = self
        copyTitleButton.action = #selector(handleCopyTitle)
        copyTitleButton.contentTintColor = NSColor(calibratedWhite: 0.12, alpha: 0.95)
        copyTitleButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy title")
        copyTitleButton.imagePosition = .imageLeading
        copyTitleButton.wantsLayer = true
        copyTitleButton.layer?.cornerRadius = 14
        copyTitleButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        copyTitleButton.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        copyTitleButton.layer?.borderWidth = 1.0
        copyTitleButton.translatesAutoresizingMaskIntoConstraints = false
        copyTitleButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        
        copyNotesButton.title = "Copy Notes"
        copyNotesButton.bezelStyle = .inline
        copyNotesButton.isBordered = false
        copyNotesButton.target = self
        copyNotesButton.action = #selector(handleCopyNotes)
        copyNotesButton.contentTintColor = NSColor(calibratedWhite: 0.12, alpha: 0.95)
        copyNotesButton.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Copy notes")
        copyNotesButton.imagePosition = .imageLeading
        copyNotesButton.wantsLayer = true
        copyNotesButton.layer?.cornerRadius = 14
        copyNotesButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        copyNotesButton.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        copyNotesButton.layer?.borderWidth = 1.0
        copyNotesButton.translatesAutoresizingMaskIntoConstraints = false
        copyNotesButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        
        for button in [copyTitleButton, copyNotesButton] {
            button.layer?.backgroundColor = NSColor.clear.cgColor
            button.layer?.borderWidth = 0
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
        }
        
        actionRow.addArrangedSubview(copyTitleButton)
        actionRow.addArrangedSubview(copyNotesButton)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        actionRow.addArrangedSubview(spacer)
        contentStack.addArrangedSubview(actionRow)
        // Let the action row use the contentStack's natural padding
        contentStack.setCustomSpacing(60, after: actionRow)
    }
    
    private func configureMetadataLabel() {
        metadataLabel.font = NSFont.systemFont(ofSize: 12 * textScale, weight: .medium) // Slightly larger
        metadataLabel.textColor = NSColor(calibratedWhite: 0.2, alpha: 1.0) // Much higher contrast
        metadataLabel.lineBreakMode = .byWordWrapping
        metadataLabel.maximumNumberOfLines = 3 // More space for information
        metadataLabel.alignment = .left
        metadataLabel.translatesAutoresizingMaskIntoConstraints = false
        metadataLabel.allowsDefaultTighteningForTruncation = false
        contentStack.addArrangedSubview(metadataLabel)
        // Let the metadata label use the contentStack's natural padding
    }
    
    private func makeMetaColumn(title: String, content: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11 * textScale, weight: .bold) // Bolder for better hierarchy
        label.textColor = NSColor(calibratedWhite: 0.25, alpha: 1.0) // Higher contrast
        label.alignment = .left

        content.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8 // Consistent spacing between label and control
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(content)

        // Ensure content fills width
        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        return stack
    }
    
    private func createDatePopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .semitransient
        
        let controller = NSViewController()
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 16
        container.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let quickRow = NSStackView()
        quickRow.orientation = .horizontal
        quickRow.spacing = 12
        quickRow.alignment = .centerY
        quickRow.distribution = .fillEqually
        
        let todayButton = quickDueButton(title: "Today")
        todayButton.target = self
        todayButton.action = #selector(handleSetDueToday)
        
        let tomorrowButton = quickDueButton(title: "Tomorrow")
        tomorrowButton.target = self
        tomorrowButton.action = #selector(handleSetDueTomorrow)
        
        let nextWeekButton = quickDueButton(title: "Next Week")
        nextWeekButton.target = self
        nextWeekButton.action = #selector(handleSetDueNextWeek)
        
        quickRow.addArrangedSubview(todayButton)
        quickRow.addArrangedSubview(tomorrowButton)
        quickRow.addArrangedSubview(nextWeekButton)
        
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        datePicker.datePickerStyle = .clockAndCalendar
        datePicker.target = self
        datePicker.action = #selector(handleDatePicked)
        datePicker.font = NSFont.systemFont(ofSize: 13 * textScale)
        
        let pickerContainer = NSView()
        pickerContainer.translatesAutoresizingMaskIntoConstraints = false
        pickerContainer.addSubview(datePicker)
        NSLayoutConstraint.activate([
            datePicker.leadingAnchor.constraint(equalTo: pickerContainer.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: pickerContainer.trailingAnchor),
            datePicker.topAnchor.constraint(equalTo: pickerContainer.topAnchor),
            datePicker.bottomAnchor.constraint(equalTo: pickerContainer.bottomAnchor)
        ])
        
        container.addArrangedSubview(quickRow)
        container.addArrangedSubview(pickerContainer)
        
        controller.view = NSView()
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(container)
        
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
            container.topAnchor.constraint(equalTo: controller.view.topAnchor),
            container.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor)
        ])
        
        controller.view.widthAnchor.constraint(equalToConstant: 300).isActive = true
        controller.view.heightAnchor.constraint(equalToConstant: 240).isActive = true
        
        popover.contentViewController = controller
        return popover
    }
    
    private func quickDueButton(title: String) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        button.bezelStyle = .inline
        button.font = NSFont.systemFont(ofSize: 13 * textScale, weight: .semibold)
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        button.wantsLayer = true
        button.layer?.cornerRadius = 12
        button.layer?.backgroundColor = orbColor.withAlphaComponent(0.22).cgColor
        button.layer?.borderColor = orbColor.highlighted().withAlphaComponent(0.4).cgColor
        button.layer?.borderWidth = 1.0
        button.contentTintColor = .white
        return button
    }
    
    private func updateUI() {
        updateStatusControl()
        updateDueButton()
        updatePriorityControl()
        updateMetadataLabel()
        updateChromePalette()
        updatePinButtonAppearance()
        updateDragStripAppearance()
    }
    
    
    private func updateStatusControl() {
        // Map task status to segment index
        // 0 = Outstanding (not started)
        // 1 = In Progress (started but not completed)
        // 2 = Complete (completed)
        let index = Int(task.status)

        statusControl.selectedSegment = index
        updateStatusColors(selectedIndex: index)
    }

    private func updateStatusColors(selectedIndex: Int) {
        // Color code based on selection
        let color: NSColor
        switch selectedIndex {
        case 0: // Outstanding
            color = NSColor.systemGray
        case 1: // In Progress
            color = NSColor.systemOrange
        case 2: // Complete
            color = NSColor.systemGreen
        default:
            color = NSColor.systemBlue
        }

        // Apply color through border to limit it to control area only
        statusControl.layer?.masksToBounds = true
        statusControl.layer?.borderColor = color.withAlphaComponent(0.5).cgColor
        statusControl.layer?.borderWidth = 1.5
        statusControl.layer?.cornerRadius = 8
        statusControl.layer?.backgroundColor = color.withAlphaComponent(0.08).cgColor
    }
    
    private func updateDueButton() {
        if let deadline = task.deadline {
            let relative = relativeFormatter.localizedString(for: deadline, relativeTo: Date())
            let absolute = dayFormatter.string(from: deadline)
            dueButton.title = "Due \(relative) • \(absolute)"

            // Check if overdue
            let isOverdue = deadline < Date()

            if isOverdue {
                // Overdue state with alert color
                dueButton.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.75).cgColor
                dueButton.contentTintColor = NSColor.white
                dueButton.layer?.shadowColor = NSColor.systemRed.withAlphaComponent(0.35).cgColor
            } else {
                // Active due date with orb color accent
                dueButton.layer?.backgroundColor = orbColor.withAlphaComponent(0.75).cgColor
                dueButton.contentTintColor = NSColor.white
                dueButton.layer?.shadowColor = orbColor.withAlphaComponent(0.3).cgColor
            }

            dueButton.layer?.borderColor = NSColor.clear.cgColor
            dueButton.layer?.borderWidth = 0
            clearDueButton.isHidden = false
            clearDueButton.contentTintColor = NSColor.white.withAlphaComponent(0.75)
        } else {
            dueButton.title = "Set due date"
            dueButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
            dueButton.layer?.borderColor = NSColor.clear.cgColor
            dueButton.layer?.borderWidth = 0
            clearDueButton.isHidden = true
            dueButton.contentTintColor = NSColor(calibratedWhite: 0.1, alpha: 0.95)
            dueButton.layer?.shadowColor = NSColor.black.withAlphaComponent(0.1).cgColor
        }
    }
    
    private func updatePriorityControl() {
        let index = priorityIndex(for: task.priority)
        applyPrioritySelection(index)
        updatePriorityColors(selectedIndex: index)
    }

    private func updatePriorityColors(selectedIndex: Int) {
        // Color code based on selection: Low = green, Med = orange, High = red
        let color: NSColor
        switch selectedIndex {
        case 0: // Low - vivid green
            color = NSColor(calibratedRed: 0.2, green: 0.9, blue: 0.3, alpha: 1.0)
        case 1: // Medium - vivid orange
            color = NSColor(calibratedRed: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
        case 2: // High - vivid red
            color = NSColor(calibratedRed: 1.0, green: 0.2, blue: 0.2, alpha: 1.0)
        default:
            color = NSColor.systemBlue
        }

        // Apply color through border to limit it to control area only
        priorityControl.layer?.masksToBounds = true // Ensure clipping
        priorityControl.layer?.borderColor = color.withAlphaComponent(0.5).cgColor
        priorityControl.layer?.borderWidth = 1.5
        priorityControl.layer?.cornerRadius = 8
        priorityControl.layer?.backgroundColor = color.withAlphaComponent(0.08).cgColor
    }
    
    
    private func updateMetadataLabel() {
        var parts: [String] = []
        parts.append(task.isCompleted ? "✓ Completed" : "○ In progress")
        if let due = task.deadline {
            let isOverdue = due < Date()
            parts.append(isOverdue ? "⚠ Overdue" : "📅 Due \(dateFormatter.string(from: due))")
        } else {
            parts.append("📅 No due date")
        }
        let index = priorityControl.selectedSegment
        if index >= 0 && index < priorityLabels.count {
            parts.append("⭐ Priority \(priorityLabels[index])")
        }
        metadataLabel.stringValue = parts.joined(separator: "  •  ")
    }

    private func updateChromePalette() {
        let fill = glassBaseFill(for: orbColor)
        chromeLayer.colors = glassGradientStops(for: orbColor)
        chromeLayer.locations = glassGradientLocations.map { NSNumber(value: Double($0)) }
        chromeLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        chromeLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        chromeLayer.backgroundColor = fill.cgColor
        backdropView.layer?.backgroundColor = fill.withAlphaComponent(0.03).cgColor
#if DEBUG
        if let locations = chromeLayer.locations {
            assert(locations.allSatisfy { $0 is NSNumber })
        }
#endif

        // Update priority control border
        priorityControl.layer?.borderColor = NSColor(calibratedWhite: 0.3, alpha: 1.0).cgColor

        // Update priority colors based on current selection
        let index = priorityIndex(for: task.priority)
        updatePriorityColors(selectedIndex: index)
    }
    
    private func updateDragStripAppearance() {
        dragStripView.updatePrimaryColor(orbColor)
    }

    private func updatePinButtonAppearance() {
        let symbolName = isPinned ? "pin.fill" : "pin"
        let tintColor = isPinned ? orbColor : NSColor(calibratedWhite: 0.4, alpha: 0.8)

        pinButton.contentTintColor = tintColor
        pinButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Pin task card")
    }
    
    @objc private func handleCloseTapped() {
        guard !isClosing else { return }
        isClosing = true
        delegate?.closeTaskDetail(for: task.id)
    }
    
    @objc private func handlePinTapped() {
        isPinned.toggle()
        if let detailWindow = window as? TaskDetailWindow {
            detailWindow.isPinned = isPinned
        }
        updatePinButtonAppearance()
        delegate?.taskDetailView(self, didTogglePin: isPinned)
    }
    
    @objc private func handleStatusChanged() {
        let selectedIndex = statusControl.selectedSegment

        // Update task status
        task.status = Int16(selectedIndex)

        // Update task completion status based on segment
        switch selectedIndex {
        case 0: // Outstanding
            task.isCompleted = false
        case 1: // In Progress
            task.isCompleted = false
        case 2: // Complete
            task.isCompleted = true
        default:
            break
        }

        updateStatusColors(selectedIndex: selectedIndex)
        updateMetadataLabel()
    }
    
    @objc private func handleDueTapped() {
        guard let window = window else { return }
        if datePopover.isShown {
            datePopover.performClose(nil)
            return
        }
        datePicker.dateValue = task.deadline ?? Date()
        datePopover.show(relativeTo: dueButton.bounds, of: dueButton, preferredEdge: .maxY)
        window.makeFirstResponder(datePicker)
    }
    
    @objc private func handleClearDue() {
        task.deadline = nil
        datePopover.performClose(nil)
        updateDueButton()
        updateMetadataLabel()
    }
    
    @objc private func handlePriorityChanged() {
        let index = priorityControl.selectedSegment
        guard index >= 0 && index < priorityValues.count else { return }
        task.priority = priorityValues[index]
        updateMetadataLabel()
        updatePriorityColors(selectedIndex: index)
    }
    
    @objc private func handleDatePicked() {
        task.deadline = datePicker.dateValue
        updateDueButton()
        updateMetadataLabel()
    }
    
    @objc private func handleSetDueToday() {
        setDue(daysFromNow: 0)
    }
    
    @objc private func handleSetDueTomorrow() {
        setDue(daysFromNow: 1)
    }
    
    @objc private func handleSetDueNextWeek() {
        setDue(daysFromNow: 7)
    }
    
    private func setDue(daysFromNow: Int) {
        let calendar = Calendar.current
        let now = Date()
        if let date = calendar.date(byAdding: .day, value: daysFromNow, to: calendar.startOfDay(for: now)) {
            task.deadline = calendar.date(byAdding: .hour, value: 9, to: date)
            datePicker.dateValue = task.deadline ?? now
            updateDueButton()
            updateMetadataLabel()
            datePopover.performClose(nil)
        }
    }
    
    @objc private func handleCopyTitle() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(task.title, forType: .string)
    }
    
    @objc private func handleCopyNotes() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(task.details, forType: .string)
    }
    
    @objc private func handleTitleEditingEnd() {
        task.title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if task.title.isEmpty {
            task.title = "Untitled Task"
            titleField.stringValue = task.title
        }
        updateMetadataLabel()
    }
    
    private func priorityIndex(for value: Int) -> Int {
        var bestIndex = 0
        var smallestDelta = Int.max
        for (index, candidate) in priorityValues.enumerated() {
            let delta = abs(candidate - value)
            if delta < smallestDelta {
                smallestDelta = delta
                bestIndex = index
            }
        }
        return bestIndex
    }
    
    private func applyPrioritySelection(_ index: Int) {
        for segment in 0..<priorityControl.segmentCount {
            priorityControl.setSelected(segment == index, forSegment: segment)
        }
    }
    
    // MARK: - Smart Notes System
    private func loadExistingNotes() {
        // Try to deserialize timestamped notes from task.details
        if !task.details.isEmpty {
            if let data = task.details.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([TimestampedNoteEntry].self, from: data) {
                timestampedNotes = decoded
            } else {
                // Legacy: Convert old plain text to a single timestamped entry
                let existingNote = TimestampedNoteEntry(content: task.details)
                timestampedNotes = [existingNote]
            }
            refreshNotesDisplay()
        }
    }
    
    private func refreshNotesDisplay() {
        // Clear existing views
        for view in notesStackView.arrangedSubviews {
            notesStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        // Add timestamped note entries
        for note in timestampedNotes.reversed() { // Show newest first
            let noteView = createNoteEntryView(for: note)
            notesStackView.addArrangedSubview(noteView)
        }
    }
    
    private func createNoteEntryView(for note: TimestampedNoteEntry) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let timestampLabel = NSTextField(labelWithString: formatTimestamp(note.timestamp))
        timestampLabel.font = NSFont.systemFont(ofSize: 10 * textScale, weight: .semibold)
        timestampLabel.textColor = NSColor(calibratedWhite: 0.35, alpha: 1.0) // Much higher contrast - dark gray
        timestampLabel.isBezeled = false
        timestampLabel.drawsBackground = false
        timestampLabel.isEditable = false
        timestampLabel.isSelectable = false
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false

        // Larger, more prominent bullet with better color
        let bulletLabel = NSTextField(labelWithString: "•")
        bulletLabel.font = NSFont.systemFont(ofSize: 16 * textScale, weight: .bold)
        bulletLabel.textColor = NSColor(calibratedWhite: 0.25, alpha: 1.0) // Much higher contrast
        bulletLabel.isBezeled = false
        bulletLabel.drawsBackground = false
        bulletLabel.isEditable = false
        bulletLabel.isSelectable = false
        bulletLabel.translatesAutoresizingMaskIntoConstraints = false

        let contentLabel = NSTextField(labelWithString: note.content)
        contentLabel.font = NSFont.systemFont(ofSize: 13 * textScale, weight: .regular)
        contentLabel.textColor = NSColor(calibratedWhite: 0.05, alpha: 1.0)
        contentLabel.isBezeled = false
        contentLabel.drawsBackground = false
        contentLabel.isEditable = false
        contentLabel.isSelectable = true
        contentLabel.lineBreakMode = .byWordWrapping
        contentLabel.usesSingleLineMode = false // Enable multi-line
        contentLabel.cell?.wraps = true // Enable wrapping at cell level
        contentLabel.cell?.isScrollable = false // Disable horizontal scrolling
        contentLabel.maximumNumberOfLines = 0 // No line limit
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal) // Allow shrinking
        // Don't set preferredMaxLayoutWidth - let it use available space
        
        container.addSubview(timestampLabel)
        container.addSubview(bulletLabel)
        container.addSubview(contentLabel)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            
            timestampLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0),
            timestampLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            timestampLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: 0),
            
            bulletLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 0),
            bulletLabel.topAnchor.constraint(equalTo: timestampLabel.bottomAnchor, constant: 4),
            bulletLabel.widthAnchor.constraint(equalToConstant: 12),
            
            contentLabel.leadingAnchor.constraint(equalTo: bulletLabel.trailingAnchor, constant: 6),
            contentLabel.topAnchor.constraint(equalTo: timestampLabel.bottomAnchor, constant: 4),
            contentLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: 0),
            contentLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        
        // Subtle separator line at bottom instead of border
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor // No background

        // Add thin separator line at bottom
        let separator = CALayer()
        separator.backgroundColor = NSColor(calibratedWhite: 0.5, alpha: 0.3).cgColor
        separator.frame = CGRect(x: 0, y: 0, width: 1000, height: 0.5) // Width will be constrained
        container.layer?.addSublayer(separator)

        return container
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    @objc private func handleNotesInput() {
        // Handle Enter key in input field - submit the note
        handleAddNote()
    }
    
    @objc private func handleAddNote() {
        let content = notesInputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !content.isEmpty {
            let newNote = TimestampedNoteEntry(content: content)
            timestampedNotes.append(newNote)
            
            // Serialize notes with timestamps to JSON
            if let encoded = try? JSONEncoder().encode(timestampedNotes),
               let jsonString = String(data: encoded, encoding: .utf8) {
                task.details = jsonString
            }
            
            refreshNotesDisplay()
            notesInputField.stringValue = ""
        }
    }
}

extension TaskDetailView {
    func prepareForClose() {
        isClosing = true
        datePopover.performClose(nil)
        window?.makeFirstResponder(nil)
        titleField.delegate = nil
        titleField.target = nil
        statusControl.target = nil
        dueButton.target = nil
        clearDueButton.target = nil
        priorityControl.target = nil
        copyTitleButton.target = nil
        copyNotesButton.target = nil
        closeButton.target = nil
        pinButton.target = nil
        delegate = nil
    }

    // MARK: - Keyboard Shortcuts
    func toggleTaskCompletion() {
        // Cycle through states: Outstanding -> In Progress -> Complete -> In Progress -> ...
        let currentIndex = statusControl.selectedSegment
        let nextIndex = (currentIndex + 1) % 3
        statusControl.selectedSegment = nextIndex
        handleStatusChanged()
    }

    func requestClose() {
        handleCloseTapped()
    }
}


// MARK: - NSTextFieldDelegate
extension TaskDetailView: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard obj.object as? NSTextField === titleField else { return }
        updateMetadataLabel()
    }
}

private final class NotesTextView: NSTextView {}


// MARK: - Task Row Helpers
struct TaskRowGeometry {
    let index: Int
    let rowRect: NSRect
    let checkboxRect: NSRect
    let dragRect: NSRect
}

struct TaskRowChip {
    let text: String
    let foreground: NSColor
    let background: NSColor
    let border: NSColor?
}

private let glassGradientLocations: [CGFloat] = [0.0, 0.55, 1.0]

func glassBaseFill(for orbColor: NSColor) -> NSColor {
    let neutral = NSColor(calibratedWhite: 1.0, alpha: 0.02)
    let accent = orbColor.withAlphaComponent(0.07)
    return neutral.blended(withFraction: 0.18, of: accent) ?? neutral
}

func glassGradientStops(for orbColor: NSColor) -> [CGColor] {
    let accent = orbColor.withAlphaComponent(0.08)
    let top = NSColor.white.withAlphaComponent(0.08).blended(withFraction: 0.1, of: accent) ?? NSColor.white.withAlphaComponent(0.08)
    let mid = NSColor.white.withAlphaComponent(0.06).blended(withFraction: 0.08, of: accent) ?? NSColor.white.withAlphaComponent(0.06)
    let bottom = NSColor.white.withAlphaComponent(0.04).blended(withFraction: 0.12, of: accent) ?? NSColor.white.withAlphaComponent(0.04)
    let palette = [top, mid, bottom]
    if let cached = GradientCache.shared.gradientColors(colors: palette, locations: glassGradientLocations) {
        return cached
    }
    return palette.map { $0.cgColor }
}


final class PassthroughVisualEffectView: NSVisualEffectView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

final class TaskDetailDragStripView: NSView {
    private let gradientLayer = CAGradientLayer()
    private let topBorder = CALayer()
    private let bottomBorder = CALayer()
    private var primaryColor: NSColor = .systemBlue
    private var isHoveringDragHandle = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        wantsLayer = true
        layer?.masksToBounds = false

        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.locations = glassGradientLocations.map { NSNumber(value: Double($0)) }
        layer?.addSublayer(gradientLayer)

        // No visible borders - match task card style
        topBorder.backgroundColor = NSColor.clear.cgColor
        bottomBorder.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(topBorder)
        layer?.addSublayer(bottomBorder)

        updateAppearance()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw drag handle pill at top center
        let dragHandleWidth: CGFloat = 48
        let dragHandleHeight: CGFloat = 5
        let topPadding: CGFloat = 12
        let dragHandleY = bounds.maxY - topPadding - dragHandleHeight
        let dragHandleRect = CGRect(
            x: bounds.midX - dragHandleWidth / 2,
            y: dragHandleY,
            width: dragHandleWidth,
            height: dragHandleHeight
        )

        let dragHandlePath = NSBezierPath(roundedRect: dragHandleRect, xRadius: dragHandleHeight / 2, yRadius: dragHandleHeight / 2)
        let dragOpacity: CGFloat = isHoveringDragHandle ? 0.25 : 0.15
        NSColor(calibratedWhite: 0.3, alpha: dragOpacity).setFill()
        dragHandlePath.fill()
    }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
        topBorder.frame = CGRect(x: bounds.minX, y: bounds.maxY - 1, width: bounds.width, height: 1)
        bottomBorder.frame = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: 1)
    }
    
    override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.push()
        window?.performDrag(with: event)
        NSCursor.pop()
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }
    
    func updatePrimaryColor(_ color: NSColor) {
        primaryColor = color
        updateAppearance()
    }
    
    private func updateAppearance() {
        gradientLayer.colors = glassGradientStops(for: primaryColor)
        gradientLayer.backgroundColor = glassBaseFill(for: primaryColor).cgColor
        gradientLayer.locations = glassGradientLocations.map { NSNumber(value: Double($0)) }
#if DEBUG
        if let locations = gradientLayer.locations {
            assert(locations.allSatisfy { $0 is NSNumber })
        }
#endif
    }
}
