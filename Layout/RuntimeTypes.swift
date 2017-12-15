//  Copyright © 2017 Schibsted. All rights reserved.

import Foundation
import CoreGraphics
import QuartzCore
import UIKit
import WebKit

public extension RuntimeType {

    // MARK: Swift

    @objc class var any: RuntimeType { return RuntimeType(Any.self) }
    @objc class var bool: RuntimeType { return RuntimeType(Bool.self) }
    @objc class var double: RuntimeType { return RuntimeType(Double.self) }
    @objc class var float: RuntimeType { return RuntimeType(Float.self) }
    @objc class var int: RuntimeType { return RuntimeType(Int.self) }
    @objc class var string: RuntimeType { return RuntimeType(String.self) }
    @objc class var uInt: RuntimeType { return RuntimeType(UInt.self) }

    // MARK: Foundation

    @objc class var anyObject: RuntimeType { return RuntimeType(AnyObject.self) }
    @objc class var selector: RuntimeType { return RuntimeType(Selector.self) }
    @objc class var nsAttributedString: RuntimeType { return RuntimeType(NSAttributedString.self) }
    @objc class var url: RuntimeType { return RuntimeType(URL.self) }
    @objc class var urlRequest: RuntimeType { return RuntimeType(URLRequest.self) }

    // MARK: CoreGraphics

    @objc class var cgAffineTransform: RuntimeType { return RuntimeType(CGAffineTransform.self) }
    @objc class var cgColor: RuntimeType { return RuntimeType(CGColor.self) }
    @objc class var cgFloat: RuntimeType { return RuntimeType(CGFloat.self) }
    @objc class var cgImage: RuntimeType { return RuntimeType(CGImage.self) }
    @objc class var cgPath: RuntimeType { return RuntimeType(CGPath.self) }
    @objc class var cgPoint: RuntimeType { return RuntimeType(CGPoint.self) }
    @objc class var cgRect: RuntimeType { return RuntimeType(CGRect.self) }
    @objc class var cgSize: RuntimeType { return RuntimeType(CGSize.self) }
    @objc class var cgVector: RuntimeType { return RuntimeType(CGVector.self) }

    // MARK: QuartzCore

    @objc class var caTransform3D: RuntimeType { return RuntimeType(CATransform3D.self) }
    @objc class var caEdgeAntialiasingMask: RuntimeType {
        return RuntimeType([
            "layerLeftEdge": .layerLeftEdge,
            "layerRightEdge": .layerRightEdge,
            "layerBottomEdge": .layerBottomEdge,
            "layerTopEdge": .layerTopEdge,
        ] as [String: CAEdgeAntialiasingMask])
    }
    @objc class var caCornerMask: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType([
                "layerMinXMinYCorner": .layerMinXMinYCorner,
                "layerMaxXMinYCorner": .layerMaxXMinYCorner,
                "layerMinXMaxYCorner": .layerMinXMaxYCorner,
                "layerMaxXMaxYCorner": .layerMaxXMaxYCorner,
            ] as [String: CACornerMask])
        }
        return RuntimeType([
            "layerMinXMinYCorner": UIntOptionSet(rawValue: 1),
            "layerMaxXMinYCorner": UIntOptionSet(rawValue: 2),
            "layerMinXMaxYCorner": UIntOptionSet(rawValue: 4),
            "layerMaxXMaxYCorner": UIntOptionSet(rawValue: 8),
        ] as [String: UIntOptionSet])
    }

    // MARK: UIKit

    @objc class var uiColor: RuntimeType { return RuntimeType(UIColor.self) }
    @objc class var uiImage: RuntimeType { return RuntimeType(UIImage.self) }
    @objc class var uiActivityType: RuntimeType {
        var values: [String: UIActivityType] = [
            "postToFacebook": .postToFacebook,
            "postToTwitter": .postToTwitter,
            "postToWeibo": .postToWeibo,
            "message": .message,
            "mail": .mail,
            "print": .print,
            "copyToPasteboard": .copyToPasteboard,
            "assignToContact": .assignToContact,
            "saveToCameraRoll": .saveToCameraRoll,
            "addToReadingList": .addToReadingList,
            "postToFlickr": .postToFlickr,
            "postToVimeo": .postToVimeo,
            "postToTencentWeibo": .postToTencentWeibo,
            "airDrop": .airDrop,
            "openInIBooks": .openInIBooks,
        ]
        if #available(iOS 11.0, *) {
            values["markupAsPDF"] = .markupAsPDF
        }
        return RuntimeType(values)
    }

    // MARK: Accessibility

    @objc class var uiAccessibilityContainerType: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType([
                "none": .none,
                "dataTable": .dataTable,
                "list": .list,
                "landmark": .landmark,
            ] as [String: UIAccessibilityContainerType])
        }
        return RuntimeType([
            "none": 0,
            "dataTable": 1,
            "list": 2,
            "landmark": 3,
        ] as [String: Int])
    }
    @objc class var uiAccessibilityNavigationStyle: RuntimeType {
        return RuntimeType([
            "automatic": .automatic,
            "separate": .separate,
            "combined": .combined,
        ] as [String: UIAccessibilityNavigationStyle])
    }
    @objc class var uiAccessibilityTraits: RuntimeType {
        let tabBarTrait: UIAccessibilityTraits
        if #available(iOS 10, *) {
            tabBarTrait = UIAccessibilityTraitTabBar
        } else {
            tabBarTrait = UIAccessibilityTraitNone
        }
        let type = RuntimeType(RuntimeType.Kind.options(UIAccessibilityTraits.self, [
            "none": UIAccessibilityTraitNone,
            "button": UIAccessibilityTraitButton,
            "link": UIAccessibilityTraitLink,
            "header": UIAccessibilityTraitHeader,
            "searchField": UIAccessibilityTraitSearchField,
            "image": UIAccessibilityTraitImage,
            "selected": UIAccessibilityTraitSelected,
            "playsSound": UIAccessibilityTraitPlaysSound,
            "keyboardKey": UIAccessibilityTraitKeyboardKey,
            "staticText": UIAccessibilityTraitStaticText,
            "summaryElement": UIAccessibilityTraitSummaryElement,
            "notEnabled": UIAccessibilityTraitNotEnabled,
            "updatesFrequently": UIAccessibilityTraitUpdatesFrequently,
            "startsMediaSession": UIAccessibilityTraitStartsMediaSession,
            "adjustable": UIAccessibilityTraitAdjustable,
            "allowsIndirectInteraction": UIAccessibilityTraitAllowsDirectInteraction,
            "causesPageTurn": UIAccessibilityTraitCausesPageTurn,
            "tabBar": tabBarTrait,
        ] as [String: UIAccessibilityTraits]))
        type.caster = { value in
            if let values = value as? [UIAccessibilityTraits] {
                return values.reduce(0) { $0 + $1 }
            }
            return value as? UIAccessibilityTraits
        }
        return type
    }

    // MARK: Geometry

    @objc class var uiBezierPath: RuntimeType { return RuntimeType(UIBezierPath.self) }
    @objc class var uiEdgeInsets: RuntimeType { return RuntimeType(UIEdgeInsets.self) }
    @objc class var uiOffset: RuntimeType { return RuntimeType(UIOffset.self) }
    @objc class var uiRectEdge: RuntimeType {
        return RuntimeType([
            "top": .top,
            "left": .left,
            "bottom": .bottom,
            "right": .right,
            "all": .all,
        ] as [String: UIRectEdge])
    }

    // MARK: Text

    @objc class var nsLineBreakMode: RuntimeType {
        return RuntimeType([
            "byWordWrapping": .byWordWrapping,
            "byCharWrapping": .byCharWrapping,
            "byClipping": .byClipping,
            "byTruncatingHead": .byTruncatingHead,
            "byTruncatingTail": .byTruncatingTail,
            "byTruncatingMiddle": .byTruncatingMiddle,
        ] as [String: NSLineBreakMode])
    }
    @objc class var nsTextAlignment: RuntimeType {
        return RuntimeType([
            "left": .left,
            "right": .right,
            "center": .center,
        ] as [String: NSTextAlignment])
    }
    @objc class var uiBaselineAdjustment: RuntimeType {
        return RuntimeType([
            "alignBaselines": .alignBaselines,
            "alignCenters": .alignCenters,
            "none": .none,
        ] as [String: UIBaselineAdjustment])
    }
    @objc class var uiDataDetectorTypes: RuntimeType {
        let types = [
            "phoneNumber": .phoneNumber,
            "link": .link,
            "address": .address,
            "calendarEvent": .calendarEvent,
            "shipmentTrackingNumber": [],
            "flightNumber": [],
            "lookupSuggestion": [],
            "all": .all,
        ] as [String: UIDataDetectorTypes]
        if #available(iOS 11.0, *) {
            var types = types
            types["shipmentTrackingNumber"] = .shipmentTrackingNumber
            types["flightNumber"] = .flightNumber
            types["lookupSuggestion"] = .lookupSuggestion
            return RuntimeType(types)
        }
        return RuntimeType(types)
    }
    @objc class var uiFont: RuntimeType {
        return RuntimeType(UIFont.self)
    }
    @objc class var uiFontDescriptorSymbolicTraits: RuntimeType {
        return RuntimeType([
            "traitItalic": .traitItalic,
            "traitBold": .traitBold,
            "traitExpanded": .traitExpanded,
            "traitCondensed": .traitCondensed,
            "traitMonoSpace": .traitMonoSpace,
            "traitVertical": .traitVertical,
            "traitUIOptimized": .traitUIOptimized,
            "traitTightLeading": .traitTightLeading,
            "traitLooseLeading": .traitLooseLeading,
        ] as [String: UIFontDescriptorSymbolicTraits])
    }
    @objc class var uiFontTextStyle: RuntimeType {
        return RuntimeType([
            "title1": .title1,
            "title2": .title2,
            "title3": .title3,
            "headline": .headline,
            "subheadline": .subheadline,
            "body": .body,
            "callout": .callout,
            "footnote": .footnote,
            "caption1": .caption1,
            "caption2": .caption2,
        ] as [String: UIFontTextStyle])
    }
    @objc class var uiFont_Weight: RuntimeType {
        return RuntimeType([
            "ultraLight": .ultraLight,
            "thin": .thin,
            "light": .light,
            "regular": .regular,
            "medium": .medium,
            "semibold": .semibold,
            "bold": .bold,
            "heavy": .heavy,
            "black": .black,
        ] as [String: UIFont.Weight])
    }

    // MARK: TextInput

    @objc class var uiKeyboardAppearance: RuntimeType {
        return RuntimeType([
            "default": .default,
            "dark": .dark,
            "light": .light,
        ] as [String: UIKeyboardAppearance])
    }
    @objc class var uiKeyboardType: RuntimeType {
        var keyboardTypes: [String: UIKeyboardType] = [
            "default": .default,
            "asciiCapable": .asciiCapable,
            "asciiCapableNumberPad": .asciiCapable,
            "numbersAndPunctuation": .numbersAndPunctuation,
            "URL": .URL,
            "url": .URL,
            "numberPad": .numberPad,
            "phonePad": .phonePad,
            "namePhonePad": .namePhonePad,
            "emailAddress": .emailAddress,
            "decimalPad": .decimalPad,
            "twitter": .twitter,
            "webSearch": .webSearch,
        ]
        if #available(iOS 10.0, *) {
            keyboardTypes["asciiCapableNumberPad"] = .asciiCapableNumberPad
        }
        return RuntimeType(keyboardTypes)
    }
    @objc class var uiReturnKeyType: RuntimeType {
        return RuntimeType([
            "default": .default,
            "go": .go,
            "google": .google,
            "join": .join,
            "next": .next,
            "route": .route,
            "search": .search,
            "send": .send,
            "yahoo": .yahoo,
            "done": .done,
            "emergencyCall": .emergencyCall,
            "continue": .continue,
        ] as [String: UIReturnKeyType])
    }
    @objc class var uiTextAutocapitalizationType: RuntimeType {
        return RuntimeType([
            "none": .none,
            "words": .words,
            "sentences": .sentences,
            "allCharacters": .allCharacters,
        ] as [String: UITextAutocapitalizationType])
    }
    @objc class var uiTextAutocorrectionType: RuntimeType {
        return RuntimeType([
            "default": .default,
            "no": .no,
            "yes": .yes,
        ] as [String: UITextAutocorrectionType])
    }
    @objc class var uiTextBorderStyle: RuntimeType {
        return RuntimeType([
            "none": .none,
            "line": .line,
            "bezel": .bezel,
            "roundedRect": .roundedRect,
        ] as [String: UITextBorderStyle])
    }
    @objc class var uiTextFieldViewMode: RuntimeType {
        return RuntimeType([
            "never": .never,
            "whileEditing": .whileEditing,
            "unlessEditing": .unlessEditing,
            "always": .always,
        ] as [String: UITextFieldViewMode])
    }
    @objc class var uiTextSmartQuotesType: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType([
                "default": .default,
                "no": .no,
                "yes": .yes,
            ] as [String: UITextSmartQuotesType])
        }
        return RuntimeType([
            "default": 0,
            "no": 1,
            "yes": 2,
        ] as [String: Int])
    }
    @objc class var uiTextSmartDashesType: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType([
                "default": .default,
                "no": .no,
                "yes": .yes,
            ] as [String: UITextSmartDashesType])
        }
        return RuntimeType([
            "default": 0,
            "no": 1,
            "yes": 2,
        ] as [String: Int])
    }
    @objc class var uiTextSmartInsertDeleteType: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType([
                "default": .default,
                "no": .no,
                "yes": .yes,
            ] as [String: UITextSmartInsertDeleteType])
        }
        return RuntimeType([
            "default": 0,
            "no": 1,
            "yes": 2,
        ] as [String: Int])
    }
    @objc class var uiTextSpellCheckingType: RuntimeType {
        return RuntimeType([
            "default": .default,
            "no": .no,
            "yes": .yes,
        ] as [String: UITextSpellCheckingType])
    }

    // MARK: Toolbars

    @objc class var uiBarStyle: RuntimeType {
        return RuntimeType([
            "default": .default,
            "black": .black,
        ] as [String: UIBarStyle])
    }
    @objc class var uiBarPosition: RuntimeType {
        return RuntimeType([
            "any": .any,
            "bottom": .bottom,
            "top": .top,
            "topAttached": .topAttached,
        ] as [String: UIBarPosition])
    }
    @objc class var uiSearchBarStyle: RuntimeType {
        return RuntimeType([
            "default": .default,
            "prominent": .prominent,
            "minimal": .minimal,
        ] as [String: UISearchBarStyle])
    }
    @objc class var uiBarButtonSystemItem: RuntimeType {
        return RuntimeType([
            "done": .done,
            "cancel": .cancel,
            "edit": .edit,
            "save": .add,
            "flexibleSpace": .flexibleSpace,
            "fixedSpace": .fixedSpace,
            "compose": .compose,
            "reply": .reply,
            "action": .action,
            "organize": .organize,
            "bookmarks": .bookmarks,
            "search": .search,
            "refresh": .refresh,
            "stop": .stop,
            "camera": .camera,
            "trash": .trash,
            "play": .play,
            "pause": .pause,
            "rewind": .rewind,
            "fastForward": .fastForward,
            "undo": .undo,
            "redo": .redo,
            "pageCurl": .pageCurl,
        ] as [String: UIBarButtonSystemItem])
    }
    @objc class var uiBarButtonItemStyle: RuntimeType {
        return RuntimeType([
            "plain": .plain,
            "done": .done,
        ] as [String: UIBarButtonItemStyle])
    }
    @objc class var uiTabBarSystemItem: RuntimeType {
        return RuntimeType([
            "more": .more,
            "favorites": .favorites,
            "featured": .featured,
            "topRated": .topRated,
            "recents": .recents,
            "contacts": .contacts,
            "history": .history,
            "bookmarks": .bookmarks,
            "search": .search,
            "downloads": .downloads,
            "mostRecent": .mostRecent,
            "mostViewed": .mostViewed,
        ] as [String: UITabBarSystemItem])
    }

    // MARK: Drag and drop

    @objc class var uiTextDragDelegate: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType(UITextDragDelegate.self)
        }
        return .anyObject
    }
    @objc class var uiTextDropDelegate: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType(UITextDropDelegate.self)
        }
        return .anyObject
    }
    @objc class var uiTextDragOptions: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType([
                "stripTextColorFromPreviews": .stripTextColorFromPreviews,
            ] as [String: UITextDragOptions])
        }
        return RuntimeType([
            "stripTextColorFromPreviews": IntOptionSet(rawValue: 1),
        ] as [String: IntOptionSet])
    }

    // MARK: UIView

    @objc class var uiViewAutoresizing: RuntimeType {
        return RuntimeType([
            "flexibleLeftMargin": .flexibleLeftMargin,
            "flexibleWidth": .flexibleWidth,
            "flexibleRightMargin": .flexibleRightMargin,
            "flexibleTopMargin": .flexibleTopMargin,
            "flexibleHeight": .flexibleHeight,
            "flexibleBottomMargin": .flexibleBottomMargin,
        ] as [String: UIViewAutoresizing])
    }
    @objc class var uiSemanticContentAttribute: RuntimeType {
        return RuntimeType([
            "unspecified": .unspecified,
            "playback": .playback,
            "spatial": .spatial,
            "forceLeftToRight": .forceLeftToRight,
            "forceRightToLeft": .forceRightToLeft,
        ] as [String: UISemanticContentAttribute])
    }
    @objc class var uiViewContentMode: RuntimeType {
        return RuntimeType([
            "scaleToFill": .scaleToFill,
            "scaleAspectFit": .scaleAspectFit,
            "scaleAspectFill": .scaleAspectFill,
            "redraw": .redraw,
            "center": .center,
            "top": .top,
            "bottom": .bottom,
            "left": .left,
            "right": .right,
            "topLeft": .topLeft,
            "topRight": .topRight,
            "bottomLeft": .bottomLeft,
            "bottomRight": .bottomRight,
        ] as [String: UIViewContentMode])
    }
    @objc class var uiViewTintAdjustmentMode: RuntimeType {
        return RuntimeType([
            "automatic": .automatic,
            "normal": .normal,
            "dimmed": .dimmed,
        ] as [String: UIViewTintAdjustmentMode])
    }

    // MARK: UIControl

    @objc class var uiControlContentVerticalAlignment: RuntimeType {
        return RuntimeType([
            "center": .center,
            "top": .top,
            "bottom": .bottom,
            "fill": .fill,
        ] as [String: UIControlContentVerticalAlignment])
    }
    @objc class var uiControlContentHorizontalAlignment: RuntimeType {
        return RuntimeType([
            "center": .center,
            "left": .left,
            "right": .right,
            "fill": .fill,
        ] as [String: UIControlContentHorizontalAlignment])
    }

    // MARK: UIButton

    @objc class var uiButtonType: RuntimeType {
        return RuntimeType([
            "custom": .custom,
            "system": .system,
            "detailDisclosure": .detailDisclosure,
            "infoLight": .infoLight,
            "infoDark": .infoDark,
            "contactAdd": .contactAdd,
        ] as [String: UIButtonType])
    }

    // MARK: UIActivityIndicatorView

    @objc class var uiActivityIndicatorViewStyle: RuntimeType {
        return RuntimeType([
            "whiteLarge": .whiteLarge,
            "white": .white,
            "gray": .gray,
        ] as [String: UIActivityIndicatorViewStyle])
    }

    // MARK: UIProgressView

    @objc class var uiProgressViewStyle: RuntimeType {
        return RuntimeType([
            "default": .default,
            "bar": .bar,
        ] as [String: UIProgressViewStyle])
    }

    // MARK: UIInputView

    @objc class var uiInputViewStyle: RuntimeType {
        return RuntimeType([
            "default": .default,
            "keyboard": .keyboard,
        ] as [String: UIInputViewStyle])
    }

    // MARK: UIDatePicker

    @objc class var uiDatePickerMode: RuntimeType {
        return RuntimeType([
            "time": .time,
            "date": .date,
            "dateAndTime": .dateAndTime,
            "countDownTimer": .countDownTimer,
        ] as [String: UIDatePickerMode])
    }

    // MARK: UIScrollView

    @objc class var uiScrollViewContentInsetAdjustmentBehavior: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType([
                "automatic": .automatic,
                "scrollableAxes": .scrollableAxes,
                "never": .never,
                "always": .always,
            ] as [String: UIScrollViewContentInsetAdjustmentBehavior])
        }
        return RuntimeType([
            "automatic": 0,
            "scrollableAxes": 1,
            "never": 2,
            "always": 3,
        ] as [String: Int])
    }
    @objc class var uiScrollViewIndicatorStyle: RuntimeType {
        return RuntimeType([
            "default": .default,
            "black": .black,
            "white": .white,
        ] as [String: UIScrollViewIndicatorStyle])
    }
    @objc class var uiScrollViewIndexDisplayMode: RuntimeType {
        return RuntimeType([
            "automatic": .automatic,
            "alwaysHidden": .alwaysHidden,
        ] as [String: UIScrollViewIndexDisplayMode])
    }
    @objc class var uiScrollViewKeyboardDismissMode: RuntimeType {
        return RuntimeType([
            "none": .none,
            "onDrag": .onDrag,
            "interactive": .interactive,
        ] as [String: UIScrollViewKeyboardDismissMode])
    }

    // MARK: UICollectionView

    @objc class var uiCollectionViewScrollDirection: RuntimeType {
        return RuntimeType([
            "horizontal": .horizontal,
            "vertical": .vertical,
        ] as [String: UICollectionViewScrollDirection])
    }
    @objc class var uiCollectionViewReorderingCadence: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType([
                "immediate": .immediate,
                "fast": .fast,
                "slow": .slow,
            ] as [String: UICollectionViewReorderingCadence])
        }
        return RuntimeType([
            "immediate": 0,
            "fast": 1,
            "slow": 2,
        ] as [String: Int])
    }
    @objc class var uiCollectionViewFlowLayoutSectionInsetReference: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType([
                "fromContentInset": .fromContentInset,
                "fromSafeArea": .fromSafeArea,
                "fromLayoutMargins": .fromLayoutMargins,
            ] as [String: UICollectionViewFlowLayoutSectionInsetReference])
        }
        return RuntimeType([
            "fromContentInset": 0,
            "fromSafeArea": 1,
            "fromLayoutMargins": 2,
        ] as [String: Int])
    }

    // MARK: UIStackView

    @objc class var uiLayoutConstraintAxis: RuntimeType {
        return RuntimeType([
            "horizontal": .horizontal,
            "vertical": .vertical,
        ] as [String: UILayoutConstraintAxis])
    }
    @objc class var uiLayoutPriority: RuntimeType {
        return RuntimeType(RuntimeType.Kind.options(UILayoutPriority.self, [
            "required": .required,
            "defaultHigh": .defaultHigh,
            "defaultLow": .defaultLow,
            "fittingSizeLevel": .fittingSizeLevel,
        ] as [String: UILayoutPriority]))
    }
    @objc class var uiStackViewDistribution: RuntimeType {
        return RuntimeType([
            "fill": .fill,
            "fillEqually": .fillEqually,
            "fillProportionally": .fillProportionally,
            "equalSpacing": .equalSpacing,
            "equalCentering": .equalCentering,
        ] as [String: UIStackViewDistribution])
    }
    @objc class var uiStackViewAlignment: RuntimeType {
        return RuntimeType([
            "fill": .fill,
            "leading": .leading,
            "top": .top,
            "firstBaseline": .firstBaseline,
            "center": .center,
            "trailing": .trailing,
            "bottom": .bottom,
            "lastBaseline": .lastBaseline, // Valid for horizontal axis only
        ] as [String: UIStackViewAlignment])
    }

    // MARK: UITableView

    @objc class var uiTableViewCellAccessoryType: RuntimeType {
        return RuntimeType([
            "none": .none,
            "disclosureIndicator": .disclosureIndicator,
            "detailDisclosureButton": .detailDisclosureButton,
            "checkmark": .checkmark,
            "detailButton": .detailButton,
        ] as [String: UITableViewCellAccessoryType])
    }
    @objc class var uiTableViewCellFocusStyle: RuntimeType {
        return RuntimeType([
            "default": .default,
            "custom": .custom,
        ] as [String: UITableViewCellFocusStyle])
    }
    @objc class var uiTableViewCellSelectionStyle: RuntimeType {
        return RuntimeType([
            "none": .none,
            "blue": .blue,
            "gray": .gray,
            "default": .default,
        ] as [String: UITableViewCellSelectionStyle])
    }
    @objc class var uiTableViewCellSeparatorStyle: RuntimeType {
        return RuntimeType([
            "none": .none,
            "singleLine": .singleLine,
            "singleLineEtched": .singleLineEtched,
        ] as [String: UITableViewCellSeparatorStyle])
    }
    @objc class var uiTableViewCellStyle: RuntimeType {
        return RuntimeType([
            "default": .default,
            "value1": .value1,
            "value2": .value2,
            "subtitle": .subtitle,
        ] as [String: UITableViewCellStyle])
    }
    @objc class var uiTableViewSeparatorInsetReference: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType([
                "fromCellEdges": .fromCellEdges,
                "fromAutomaticInsets": .fromAutomaticInsets,
            ] as [String: UITableViewSeparatorInsetReference])
        }
        return RuntimeType([
            "fromCellEdges": 0,
            "fromAutomaticInsets": 1,
        ] as [String: Int])
    }
    @objc class var uiTableViewStyle: RuntimeType {
        return RuntimeType([
            "plain": .plain,
            "grouped": .grouped,
        ] as [String: UITableViewStyle])
    }

    // MARK: UIWebView

    @objc class var uiWebPaginationMode: RuntimeType {
        return RuntimeType([
            "unpaginated": .unpaginated,
            "leftToRight": .leftToRight,
            "topToBottom": .topToBottom,
            "bottomToTop": .bottomToTop,
            "rightToLeft": .rightToLeft,
        ] as [String: UIWebPaginationMode])
    }
    @objc class var uiWebPaginationBreakingMode: RuntimeType {
        return RuntimeType([
            "page": .page,
            "column": .column,
        ] as [String: UIWebPaginationBreakingMode])
    }

    // MARK: WebKit

    @objc class var wkAudiovisualMediaTypes: RuntimeType {
        if #available(iOS 10, *) {
            return RuntimeType([
                "audio": .audio,
                "video": .video,
                "all": .all,
            ] as [String: WKAudiovisualMediaTypes])
        }
        return RuntimeType([
            "audio": IntOptionSet(rawValue: 1),
            "video": IntOptionSet(rawValue: 2),
            "all": IntOptionSet(rawValue: 3),
        ] as [String: IntOptionSet])
    }
    @objc class var wkDataDetectorTypes: RuntimeType {
        if #available(iOS 10, *) {
            return RuntimeType([
                "phoneNumber": .phoneNumber,
                "link": .link,
                "address": .address,
                "calendarEvent": .calendarEvent,
                "trackingNumber": .trackingNumber,
                "flightNumber": .flightNumber,
                "lookupSuggestion": .lookupSuggestion,
                "all": .all,
            ] as [String: WKDataDetectorTypes])
        }
        return RuntimeType([
            "phoneNumber": IntOptionSet(rawValue: 1),
            "link": IntOptionSet(rawValue: 2),
            "address": IntOptionSet(rawValue: 4),
            "calendarEvent": IntOptionSet(rawValue: 8),
            "trackingNumber": IntOptionSet(rawValue: 16),
            "flightNumber": IntOptionSet(rawValue: 32),
            "lookupSuggestion": IntOptionSet(rawValue: 64),
            "all": IntOptionSet(rawValue: 127),
        ] as [String: IntOptionSet])
    }
    @objc class var wkSelectionGranularity: RuntimeType {
        return RuntimeType([
            "dynamic": .dynamic,
            "character": .character,
        ] as [String: WKSelectionGranularity])
    }

    // MARK: UIViewController

    @objc class var uiModalPresentationStyle: RuntimeType {
        return RuntimeType([
            "fullScreen": .fullScreen,
            "pageSheet": .pageSheet,
            "formSheet": .formSheet,
            "currentContext": .currentContext,
            "custom": .custom,
            "overFullScreen": .overFullScreen,
            "overCurrentContext": .overCurrentContext,
            "popover": .popover,
            "none": .none,
        ] as [String: UIModalPresentationStyle])
    }
    @objc class var uiModalTransitionStyle: RuntimeType {
        return RuntimeType([
            "coverVertical": .coverVertical,
            "flipHorizontal": .flipHorizontal,
            "crossDissolve": .crossDissolve,
            "partialCurl": .partialCurl,
        ] as [String: UIModalTransitionStyle])
    }
    @objc class var uiNavigationItem_LargeTitleDisplayMode: RuntimeType {
        return RuntimeType([
            "automatic": .automatic,
            "always": .always,
            "never": .never,
        ] as [String: UINavigationItem.LargeTitleDisplayMode])
    }

    // MARK: UICloudSharingViewController

    @objc class var uiCloudSharingPermissionOptions: RuntimeType {
        if #available(iOS 10.0, *) {
            return RuntimeType([
                "allowPublic": .allowPublic,
                "allowPrivate": .allowPrivate,
                "allowReadOnly": .allowReadOnly,
                "allowReadWrite": .allowReadWrite,
            ] as [String: UICloudSharingPermissionOptions])
        }
        return RuntimeType([
            "allowPublic": 0,
            "allowPrivate": 1,
            "allowReadOnly": 2,
            "allowReadWrite": 3,
        ] as [String: Int])
    }

    // MARK: UIImagePickerController

    @objc class var uiImagePickerControllerCameraCaptureMode: RuntimeType {
        return RuntimeType([
            "photo": .photo,
            "video": .video,
        ] as [String: UIImagePickerControllerCameraCaptureMode])
    }
    @objc class var uiImagePickerControllerCameraDevice: RuntimeType {
        return RuntimeType([
            "rear": .rear,
            "front": .front,
        ] as [String: UIImagePickerControllerCameraDevice])
    }
    @objc class var uiImagePickerControllerCameraFlashMode: RuntimeType {
        return RuntimeType([
            "off": .off,
            "auto": .auto,
            "on": .on,
        ] as [String: UIImagePickerControllerCameraFlashMode])
    }
    @objc class var uiImagePickerControllerImageURLExportPreset: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType([
                "compatible": .compatible,
                "current": .current,
            ] as [String: UIImagePickerControllerImageURLExportPreset])
        }
        return RuntimeType([
            "compatible": IntOptionSet(rawValue: 1),
            "current": IntOptionSet(rawValue: 2),
        ] as [String: IntOptionSet])
    }
    @objc class var uiImagePickerControllerSourceType: RuntimeType {
        return RuntimeType([
            "photoLibrary": .photoLibrary,
            "camera": .camera,
            "savedPhotosAlbum": .savedPhotosAlbum,
        ] as [String: UIImagePickerControllerSourceType])
    }
    @objc class var uiImagePickerControllerQualityType: RuntimeType {
        return RuntimeType([
            "typeHigh": .typeHigh,
            "typeMedium": .typeMedium,
            "typeLow": .typeLow,
            "type640x480": .type640x480,
            "typeIFrame1280x720": .typeIFrame1280x720,
            "typeIFrame960x540": .typeIFrame960x540,
        ] as [String: UIImagePickerControllerQualityType])
    }

    // MARK: UISplitViewController

    @objc class var uiSplitViewControllerDisplayMode: RuntimeType {
        return RuntimeType([
            "automatic": .automatic,
            "primaryHidden": .primaryHidden,
            "allVisible": .allVisible,
            "primaryOverlay": .primaryOverlay,
        ] as [String: UISplitViewControllerDisplayMode])
    }
    @objc class var uiSplitViewControllerPrimaryEdge: RuntimeType {
        if #available(iOS 11.0, *) {
            return RuntimeType([
                "leading": .leading,
                "trailing": .trailing,
            ] as [String: UISplitViewControllerPrimaryEdge])
        }
        return RuntimeType([
            "leading": 0,
            "trailing": 1,
        ] as [String: Int])
    }
}
