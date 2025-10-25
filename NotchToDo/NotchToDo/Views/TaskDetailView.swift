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
    private let headerGradientLayer = CAGradientLayer()
    private let dragStripView = TaskDetailDragStripView()
    
    private let headerBar = NSView()
    private let orbBadge = NSView()
    private let titleField = NSTextField()
    private let headerSubtitleLabel = NSTextField(labelWithString: "")
    private let closeButton = NSButton()
    private let pinButton = NSButton()
    
    private let metaRow = NSStackView()
    private let statusButton = NSButton()
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
        configureHeader()
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
        headerGradientLayer.frame = headerBar.bounds
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let detailWindow = window as? TaskDetailWindow {
            isPinned = detailWindow.isPinned
            updatePinButtonAppearance()
        }
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
        contentStack.spacing = 30
        contentStack.alignment = .leading
        contentStack.edgeInsets = NSEdgeInsets(top: 50, left: 60, bottom: 0, right: 60)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        backdropView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: backdropView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: backdropView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: backdropView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: backdropView.bottomAnchor)
        ])
    }
    
    private func configureHeader() {
        headerBar.translatesAutoresizingMaskIntoConstraints = false
        headerBar.wantsLayer = true
        headerBar.layer?.cornerRadius = 22
        headerBar.layer?.masksToBounds = true
        headerGradientLayer.cornerRadius = 22
        headerGradientLayer.masksToBounds = true
        headerGradientLayer.opacity = 0.6
        headerGradientLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
        headerGradientLayer.endPoint = CGPoint(x: 1.0, y: 0.0)
        headerGradientLayer.colors = [
            NSColor.white.withAlphaComponent(0.36).cgColor,
            orbColor.withAlphaComponent(0.18).cgColor
        ]
        headerGradientLayer.locations = [NSNumber(value: 0.0), NSNumber(value: 1.0)]
        headerBar.layer?.insertSublayer(headerGradientLayer, at: 0)
        headerBar.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        headerBar.layer?.borderWidth = 0.8
        
        orbBadge.wantsLayer = true
        orbBadge.layer?.cornerRadius = 7
        orbBadge.layer?.backgroundColor = orbColor.cgColor
        orbBadge.layer?.shadowColor = orbColor.withAlphaComponent(0.6).cgColor
        orbBadge.layer?.shadowOpacity = 0.8
        orbBadge.layer?.shadowOffset = .zero
        orbBadge.layer?.shadowRadius = 6
        orbBadge.translatesAutoresizingMaskIntoConstraints = false
        orbBadge.widthAnchor.constraint(equalToConstant: 14).isActive = true
        orbBadge.heightAnchor.constraint(equalToConstant: 14).isActive = true
        
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.isEditable = true
        titleField.isBordered = false
        titleField.drawsBackground = false
        titleField.focusRingType = .none
        titleField.font = NSFont.systemFont(ofSize: 27 * textScale, weight: .semibold)
        titleField.textColor = NSColor(calibratedWhite: 0.08, alpha: 0.95)
        titleField.alignment = .left
        titleField.lineBreakMode = .byTruncatingTail
        titleField.stringValue = task.title
        titleField.delegate = self
        titleField.target = self
        titleField.action = #selector(handleTitleEditingEnd)
        
        headerSubtitleLabel.font = NSFont.systemFont(ofSize: 13 * textScale, weight: .medium)
        headerSubtitleLabel.textColor = NSColor(calibratedWhite: 0.35, alpha: 0.9)
        headerSubtitleLabel.alignment = .left
        headerSubtitleLabel.lineBreakMode = .byTruncatingTail
        headerSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let textColumn = NSStackView()
        textColumn.orientation = .vertical
        textColumn.alignment = .leading
        textColumn.spacing = 6
        textColumn.translatesAutoresizingMaskIntoConstraints = false
        textColumn.addArrangedSubview(titleField)
        textColumn.addArrangedSubview(headerSubtitleLabel)
        
        let headerStack = NSStackView()
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 22
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(orbBadge)
        headerStack.addArrangedSubview(textColumn)
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        headerStack.addArrangedSubview(spacer)
        textColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        headerBar.addSubview(headerStack)
        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 32),
            headerStack.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor, constant: -32),
            headerStack.topAnchor.constraint(equalTo: headerBar.topAnchor, constant: 26),
            headerStack.bottomAnchor.constraint(equalTo: headerBar.bottomAnchor, constant: -26)
        ])
        
        contentStack.addArrangedSubview(headerBar)
        // Let the header bar use the contentStack's natural padding
        contentStack.setCustomSpacing(30, after: headerBar)
    }

    private func configureChromeButtons() {
        let buttons = [closeButton, pinButton]
        let buttonSize: CGFloat = 14
        let horizontalInset: CGFloat = max(CGFloat(10), TaskRowMetrics.cardInset - 10)
        let offBlack = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        
        for button in buttons {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.isBordered = false
            button.bezelStyle = .shadowlessSquare
            button.imagePosition = .imageOnly
            button.focusRingType = .none
            button.wantsLayer = true
            button.layer?.cornerRadius = buttonSize / 2
            button.layer?.backgroundColor = offBlack.withAlphaComponent(0.12).cgColor
            button.layer?.masksToBounds = false
            button.imageScaling = .scaleProportionallyDown
            button.setContentHuggingPriority(.required, for: .horizontal)
            dragStripView.addSubview(button)
        }
        
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close task")
        closeButton.contentTintColor = offBlack.withAlphaComponent(0.95)
        closeButton.target = self
        closeButton.action = #selector(handleCloseTapped)
        closeButton.toolTip = "Close"
        
        pinButton.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin task card")
        pinButton.contentTintColor = offBlack.withAlphaComponent(0.95)
        pinButton.target = self
        pinButton.action = #selector(handlePinTapped)
        pinButton.toolTip = "Pin"
        
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: dragStripView.leadingAnchor, constant: horizontalInset),
            closeButton.topAnchor.constraint(equalTo: dragStripView.topAnchor, constant: 4),
            closeButton.widthAnchor.constraint(equalToConstant: buttonSize),
            closeButton.heightAnchor.constraint(equalTo: closeButton.widthAnchor),
            
            pinButton.trailingAnchor.constraint(equalTo: dragStripView.trailingAnchor, constant: -horizontalInset),
            pinButton.topAnchor.constraint(equalTo: dragStripView.topAnchor, constant: 4),
            pinButton.widthAnchor.constraint(equalToConstant: buttonSize),
            pinButton.heightAnchor.constraint(equalTo: pinButton.widthAnchor)
        ])
        
        updateChromeButtonsAppearance()
        updatePinButtonAppearance()
    }
    
    private func configureMetaRow() {
        metaRow.orientation = .horizontal
        metaRow.alignment = .top
        metaRow.spacing = 20
        metaRow.distribution = .fill
        metaRow.translatesAutoresizingMaskIntoConstraints = false
        metaRow.edgeInsets = NSEdgeInsets(top: 0, left: 30, bottom: 0, right: 30)
        contentStack.addArrangedSubview(metaRow)
        // Let the meta row use the contentStack's natural padding
        contentStack.setCustomSpacing(0, after: metaRow)
        
        // Force the meta row to stick to the bottom with a bit more space
        NSLayoutConstraint.activate([
            metaRow.bottomAnchor.constraint(equalTo: contentStack.bottomAnchor, constant: -15)
        ])
        
        statusButton.title = ""
        statusButton.isBordered = false
        statusButton.wantsLayer = true
        statusButton.layer?.cornerRadius = 14
        statusButton.target = self
        statusButton.action = #selector(handleStatusToggle)
        statusButton.font = NSFont.systemFont(ofSize: 14 * textScale, weight: .semibold)
        statusButton.contentTintColor = .white
        statusButton.imagePosition = .imageLeading
        statusButton.translatesAutoresizingMaskIntoConstraints = false
        statusButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        statusButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        statusButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        dueButton.title = "Set due date"
        dueButton.isBordered = false
        dueButton.wantsLayer = true
        dueButton.layer?.cornerRadius = 14
        dueButton.target = self
        dueButton.action = #selector(handleDueTapped)
        dueButton.font = NSFont.systemFont(ofSize: 14 * textScale, weight: .medium)
        dueButton.contentTintColor = .white
        dueButton.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Set due date")
        dueButton.imagePosition = .imageLeading
        dueButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        dueButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        dueButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        
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
        
        priorityControl.segmentStyle = .automatic
        priorityControl.target = self
        priorityControl.action = #selector(handlePriorityChanged)
        priorityControl.translatesAutoresizingMaskIntoConstraints = false
        priorityControl.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        priorityControl.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let statusColumn = makeMetaColumn(title: "STATUS", content: statusButton)
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
        notesLabel.font = NSFont.systemFont(ofSize: 12 * textScale, weight: .heavy)
        notesLabel.textColor = NSColor(calibratedWhite: 0.35, alpha: 0.9)
        notesLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(notesLabel)
        contentStack.setCustomSpacing(20, after: notesLabel)
        
        // Configure notes stack view for timestamped entries
        notesStackView.orientation = .vertical
        notesStackView.alignment = .leading
        notesStackView.spacing = 12
        notesStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure scroll view
        notesScrollView.translatesAutoresizingMaskIntoConstraints = false
        notesScrollView.borderType = .noBorder
        notesScrollView.drawsBackground = false
        notesScrollView.hasVerticalScroller = true
        notesScrollView.wantsLayer = true
        notesScrollView.layer?.cornerRadius = 16
        notesScrollView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.08).cgColor
        notesScrollView.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        notesScrollView.layer?.borderWidth = 1.0
        notesScrollView.layer?.masksToBounds = true
        notesScrollView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        
        notesScrollView.documentView = notesStackView
        
        // Configure input field and button
        notesInputField.translatesAutoresizingMaskIntoConstraints = false
        notesInputField.isBordered = true
        notesInputField.isBezeled = true
        notesInputField.bezelStyle = .roundedBezel
        notesInputField.font = NSFont.systemFont(ofSize: 13 * textScale, weight: .regular)
        notesInputField.textColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        notesInputField.backgroundColor = NSColor.white.withAlphaComponent(0.12)
        notesInputField.placeholderString = "Add a note..."
        notesInputField.target = self
        notesInputField.action = #selector(handleNotesInput)
        
        notesInputButton.translatesAutoresizingMaskIntoConstraints = false
        notesInputButton.title = "Add"
        notesInputButton.bezelStyle = .inline
        notesInputButton.isBordered = false
        notesInputButton.font = NSFont.systemFont(ofSize: 12 * textScale, weight: .medium)
        notesInputButton.wantsLayer = true
        notesInputButton.layer?.cornerRadius = 8
        notesInputButton.layer?.backgroundColor = orbColor.withAlphaComponent(0.2).cgColor
        notesInputButton.contentTintColor = orbColor
        notesInputButton.target = self
        notesInputButton.action = #selector(handleAddNote)
        
        let inputRow = NSStackView()
        inputRow.orientation = .horizontal
        inputRow.spacing = 8
        inputRow.alignment = .centerY
        inputRow.distribution = .fill
        inputRow.translatesAutoresizingMaskIntoConstraints = false
        inputRow.addArrangedSubview(notesInputField)
        inputRow.addArrangedSubview(notesInputButton)
        
        notesInputButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
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
        metadataLabel.font = NSFont.systemFont(ofSize: 11 * textScale, weight: .medium)
        metadataLabel.textColor = NSColor(calibratedWhite: 0.4, alpha: 0.9)
        metadataLabel.lineBreakMode = .byWordWrapping
        metadataLabel.maximumNumberOfLines = 2
        metadataLabel.alignment = .left
        metadataLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(metadataLabel)
        // Let the metadata label use the contentStack's natural padding
    }
    
    private func makeMetaColumn(title: String, content: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11 * textScale, weight: .semibold)
        label.textColor = NSColor(calibratedWhite: 0.28, alpha: 0.9)
        label.alignment = .left
        
        content.translatesAutoresizingMaskIntoConstraints = false
        
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(content)
        
        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            stack.topAnchor.constraint(equalTo: wrapper.topAnchor),
            stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])
        
        return wrapper
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
        updateStatusButton()
        updateDueButton()
        updatePriorityControl()
        updateMetadataLabel()
        updateHeaderSubtitle()
        updateChromePalette()
        updateChromeButtonsAppearance()
        updatePinButtonAppearance()
        updateDragStripAppearance()
    }
    
    private func updateHeaderSubtitle() {
        var parts: [String] = []
        parts.append(task.isCompleted ? "Completed" : "Active")
        if let due = task.deadline {
            let relative = relativeFormatter.localizedString(for: due, relativeTo: Date())
            let absolute = dayFormatter.string(from: due)
            parts.append("\(relative.capitalized) • \(absolute)")
        } else {
            parts.append("No due date")
        }
        let priorityIndex = priorityIndex(for: task.priority)
        if priorityIndex >= 0 && priorityIndex < priorityLabels.count {
            parts.append("Priority \(priorityLabels[priorityIndex])")
        }
        headerSubtitleLabel.stringValue = parts.joined(separator: " · ")
    }
    
    private func updateStatusButton() {
        let isDone = task.isCompleted
        statusButton.title = isDone ? "Reopen Task" : "Mark Complete"
        statusButton.image = NSImage(systemSymbolName: isDone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill", accessibilityDescription: nil)
        let background = isDone ? NSColor.systemGreen.withAlphaComponent(0.35) : NSColor.white.withAlphaComponent(0.18)
        statusButton.layer?.backgroundColor = background.cgColor
        statusButton.layer?.borderColor = NSColor.clear.cgColor
        statusButton.layer?.borderWidth = 0
        statusButton.contentTintColor = isDone ? NSColor.white : NSColor(calibratedWhite: 0.1, alpha: 0.95)
        updateHeaderSubtitle()
    }
    
    private func updateDueButton() {
        if let deadline = task.deadline {
            let relative = relativeFormatter.localizedString(for: deadline, relativeTo: Date())
            let absolute = dayFormatter.string(from: deadline)
            dueButton.title = "Due \(relative) • \(absolute)"
            dueButton.layer?.backgroundColor = orbColor.withAlphaComponent(0.22).cgColor
            dueButton.layer?.borderColor = NSColor.clear.cgColor
            dueButton.layer?.borderWidth = 0
            clearDueButton.isHidden = false
            clearDueButton.contentTintColor = NSColor.white.withAlphaComponent(0.7)
            dueButton.contentTintColor = NSColor.white
        } else {
            dueButton.title = "Set due date"
            dueButton.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
            dueButton.layer?.borderColor = NSColor.clear.cgColor
            dueButton.layer?.borderWidth = 0
            clearDueButton.isHidden = true
            dueButton.contentTintColor = NSColor(calibratedWhite: 0.1, alpha: 0.95)
        }
        updateHeaderSubtitle()
    }
    
    private func updatePriorityControl() {
        let index = priorityIndex(for: task.priority)
        applyPrioritySelection(index)
        updateHeaderSubtitle()
    }
    
    
    private func updateMetadataLabel() {
        var parts: [String] = []
        parts.append(task.isCompleted ? "Completed" : "In progress")
        if let due = task.deadline {
            parts.append("Due \(dateFormatter.string(from: due))")
        } else {
            parts.append("No due date")
        }
        let index = priorityControl.selectedSegment
        if index >= 0 && index < priorityLabels.count {
            parts.append("Priority \(priorityLabels[index])")
        }
        metadataLabel.stringValue = parts.joined(separator: "   •   ")
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
        updateChromeButtonsAppearance()
    }
    
    private func updateDragStripAppearance() {
        dragStripView.updatePrimaryColor(orbColor)
    }
    
    private func updateChromeButtonsAppearance() {
        let closeFill = orbColor.withAlphaComponent(0.24)
        closeButton.layer?.backgroundColor = closeFill.cgColor
        closeButton.contentTintColor = orbColor.shadowed().withAlphaComponent(0.95)
        closeButton.layer?.shadowColor = orbColor.withAlphaComponent(0.3).cgColor
        closeButton.layer?.shadowOpacity = 0.25
        closeButton.layer?.shadowRadius = 6
        closeButton.layer?.shadowOffset = CGSize(width: 0, height: -1)
        
        pinButton.layer?.shadowColor = orbColor.withAlphaComponent(0.25).cgColor
        pinButton.layer?.shadowOpacity = 0.22
        pinButton.layer?.shadowRadius = 6
        pinButton.layer?.shadowOffset = CGSize(width: 0, height: -1)
    }
    
    private func updatePinButtonAppearance() {
        let offBlack = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        let fillColor: NSColor
        let symbolName: String
        let tintColor: NSColor
        
        if isPinned {
            fillColor = orbColor.withAlphaComponent(0.38)
            symbolName = "pin.fill"
            tintColor = NSColor(calibratedWhite: 0.08, alpha: 0.95)
        } else {
            fillColor = orbColor.withAlphaComponent(0.18)
            symbolName = "pin"
            tintColor = orbColor.shadowed().withAlphaComponent(0.9)
        }
        
        pinButton.layer?.backgroundColor = fillColor.cgColor
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
    
    @objc private func handleStatusToggle() {
        task.isCompleted.toggle()
        updateStatusButton()
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
        updateHeaderSubtitle()
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
        timestampLabel.font = NSFont.systemFont(ofSize: 10 * textScale, weight: .medium)
        timestampLabel.textColor = NSColor(calibratedWhite: 0.4, alpha: 0.8)
        timestampLabel.isBezeled = false
        timestampLabel.drawsBackground = false
        timestampLabel.isEditable = false
        timestampLabel.isSelectable = false
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add bullet point before content
        let bulletLabel = NSTextField(labelWithString: "•")
        bulletLabel.font = NSFont.systemFont(ofSize: 14 * textScale, weight: .bold)
        bulletLabel.textColor = orbColor.withAlphaComponent(0.8)
        bulletLabel.isBezeled = false
        bulletLabel.drawsBackground = false
        bulletLabel.isEditable = false
        bulletLabel.isSelectable = false
        bulletLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let contentLabel = NSTextField(labelWithString: note.content)
        contentLabel.font = NSFont.systemFont(ofSize: 12 * textScale, weight: .regular)
        contentLabel.textColor = NSColor(calibratedWhite: 0.15, alpha: 1.0)
        contentLabel.isBezeled = false
        contentLabel.drawsBackground = false
        contentLabel.isEditable = false
        contentLabel.isSelectable = true
        contentLabel.lineBreakMode = .byWordWrapping
        contentLabel.maximumNumberOfLines = 0
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        
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
        
        // Add subtle background
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
        container.layer?.cornerRadius = 8
        
        return container
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    @objc private func handleNotesInput() {
        // Handle Enter key in input field
        if NSEvent.modifierFlags.contains(.command) {
            handleAddNote()
        }
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
        statusButton.target = nil
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
        handleStatusToggle()
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
        
        topBorder.backgroundColor = NSColor.white.withAlphaComponent(0.35).cgColor
        bottomBorder.backgroundColor = NSColor.black.withAlphaComponent(0.08).cgColor
        layer?.addSublayer(topBorder)
        layer?.addSublayer(bottomBorder)
        
        updateAppearance()
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
