import Cocoa
import QuartzCore

// MARK: - Task Detail View
protocol TaskDetailViewDelegate: AnyObject {
    func closeTaskDetail(for taskId: UUID)
    func taskDetailView(_ view: TaskDetailView, didTogglePin isPinned: Bool)
}

class TaskDetailView: NSView {
    private var task: Task
    private var orbColor: NSColor
    private weak var delegate: TaskDetailViewDelegate?
    
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
    private let notesTextView = NotesTextView()
    private let notesPlaceholder = NSTextField(labelWithString: "Add any details, decisions, or next steps…")
    
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
        super.init(frame: NSRect(x: 0, y: 0, width: 440, height: 560))
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
        configureMetaRow()
        configureNotesSection()
        configureActionRow()
        configureMetadataLabel()
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
        contentStack.spacing = 48
        contentStack.alignment = .leading
        contentStack.edgeInsets = NSEdgeInsets(top: 84, left: 72, bottom: 68, right: 72)
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
        titleField.font = NSFont.systemFont(ofSize: 27, weight: .semibold)
        titleField.textColor = NSColor(calibratedWhite: 0.08, alpha: 0.95)
        titleField.alignment = .left
        titleField.lineBreakMode = .byTruncatingTail
        titleField.stringValue = task.title
        titleField.delegate = self
        titleField.target = self
        titleField.action = #selector(handleTitleEditingEnd)
        
        headerSubtitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
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
        headerBar.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        headerBar.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
        contentStack.setCustomSpacing(56, after: headerBar)
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
        metaRow.spacing = 36
        metaRow.distribution = .fillEqually
        metaRow.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(metaRow)
        metaRow.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        metaRow.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
        contentStack.setCustomSpacing(48, after: metaRow)
        
        statusButton.title = ""
        statusButton.isBordered = false
        statusButton.wantsLayer = true
        statusButton.layer?.cornerRadius = 14
        statusButton.target = self
        statusButton.action = #selector(handleStatusToggle)
        statusButton.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        statusButton.contentTintColor = .white
        statusButton.imagePosition = .imageLeading
        statusButton.translatesAutoresizingMaskIntoConstraints = false
        statusButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        statusButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        statusButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        dueButton.title = "Set due date"
        dueButton.isBordered = false
        dueButton.wantsLayer = true
        dueButton.layer?.cornerRadius = 14
        dueButton.target = self
        dueButton.action = #selector(handleDueTapped)
        dueButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        dueButton.contentTintColor = .white
        dueButton.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Set due date")
        dueButton.imagePosition = .imageLeading
        dueButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        dueButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        dueButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        
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
        priorityControl.widthAnchor.constraint(equalToConstant: 210).isActive = true
        
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
        notesLabel.font = NSFont.systemFont(ofSize: 12, weight: .heavy)
        notesLabel.textColor = NSColor(calibratedWhite: 0.35, alpha: 0.9)
        notesLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(notesLabel)
        contentStack.setCustomSpacing(32, after: notesLabel)
        
        notesScrollView.translatesAutoresizingMaskIntoConstraints = false
        notesScrollView.borderType = .noBorder
        notesScrollView.drawsBackground = false
        notesScrollView.hasVerticalScroller = true
        notesScrollView.wantsLayer = true
        notesScrollView.layer?.cornerRadius = 26
        notesScrollView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        notesScrollView.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        notesScrollView.layer?.borderWidth = 1.0
        notesScrollView.layer?.masksToBounds = true
        notesScrollView.heightAnchor.constraint(equalToConstant: 240).isActive = true
        
        notesTextView.backgroundColor = .clear
        notesTextView.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        notesTextView.textColor = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        notesTextView.insertionPointColor = NSColor(calibratedWhite: 0.2, alpha: 1.0)
        notesTextView.isRichText = false
        notesTextView.isAutomaticQuoteSubstitutionEnabled = false
        notesTextView.isAutomaticSpellingCorrectionEnabled = false
        notesTextView.isAutomaticDataDetectionEnabled = true
        notesTextView.isHorizontallyResizable = false
        notesTextView.isVerticallyResizable = true
        notesTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        notesTextView.delegate = self
        notesTextView.string = task.details
        notesTextView.textContainerInset = NSSize(width: 26, height: 26)
        notesTextView.textContainer?.widthTracksTextView = true
        
        notesScrollView.documentView = notesTextView
        notesPlaceholder.font = NSFont.systemFont(ofSize: 14)
        notesPlaceholder.textColor = NSColor(calibratedWhite: 0.45, alpha: 0.9)
        notesPlaceholder.isBezeled = false
        notesPlaceholder.drawsBackground = false
        notesPlaceholder.isEditable = false
        notesPlaceholder.isSelectable = false
        notesPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        notesPlaceholder.lineBreakMode = .byWordWrapping
        notesPlaceholder.maximumNumberOfLines = 2
        notesTextView.addSubview(notesPlaceholder)
        NSLayoutConstraint.activate([
            notesPlaceholder.leadingAnchor.constraint(equalTo: notesTextView.leadingAnchor, constant: 30),
            notesPlaceholder.topAnchor.constraint(equalTo: notesTextView.topAnchor, constant: 28),
            notesPlaceholder.trailingAnchor.constraint(lessThanOrEqualTo: notesTextView.trailingAnchor, constant: -30)
        ])
        
        contentStack.addArrangedSubview(notesScrollView)
        notesScrollView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        notesScrollView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
        contentStack.setCustomSpacing(44, after: notesScrollView)
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
        actionRow.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        actionRow.trailingAnchor.constraint(lessThanOrEqualTo: contentStack.trailingAnchor).isActive = true
        contentStack.setCustomSpacing(40, after: actionRow)
    }
    
    private func configureMetadataLabel() {
        metadataLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        metadataLabel.textColor = NSColor(calibratedWhite: 0.4, alpha: 0.9)
        metadataLabel.lineBreakMode = .byWordWrapping
        metadataLabel.maximumNumberOfLines = 2
        metadataLabel.alignment = .left
        metadataLabel.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(metadataLabel)
        metadataLabel.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        metadataLabel.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
    }
    
    private func makeMetaColumn(title: String, content: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
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
            stack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -16)
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
        datePicker.font = NSFont.systemFont(ofSize: 13)
        
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
        button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
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
        updateNotesPlaceholder()
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
    
    private func updateNotesPlaceholder() {
        let text = notesTextView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        notesPlaceholder.isHidden = !text.isEmpty
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
}

extension TaskDetailView {
    func prepareForClose() {
        isClosing = true
        datePopover.performClose(nil)
        window?.makeFirstResponder(nil)
        notesTextView.delegate = nil
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
}

// MARK: - NSTextViewDelegate
extension TaskDetailView: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard notification.object as? NSTextView === notesTextView else {
            return
        }
        task.details = notesTextView.string
        updateNotesPlaceholder()
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
