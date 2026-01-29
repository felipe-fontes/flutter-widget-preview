/**
 * Device resolution presets for Flutter widget preview.
 * 
 * Values are based on official device specifications:
 * - Logical size = what Flutter sees in MediaQuery.of(context).size
 * - Physical size = logical size × devicePixelRatio
 */

export interface DeviceResolution {
    /** Display name shown in picker */
    name: string;
    /** Category for grouping in picker */
    category: 'iOS' | 'Android' | 'Desktop' | 'Custom';
    /** Logical width (Flutter logical pixels) */
    width: number;
    /** Logical height (Flutter logical pixels) */
    height: number;
    /** Device pixel ratio (physical pixels / logical pixels) */
    devicePixelRatio: number;
}

/**
 * Pre-configured device resolution presets.
 * Physical dimensions = logical dimensions × devicePixelRatio
 */
export const DEVICE_RESOLUTIONS: DeviceResolution[] = [
    // iOS Devices
    {
        name: 'iPhone 15 Pro',
        category: 'iOS',
        width: 393,
        height: 852,
        devicePixelRatio: 3,
    },
    {
        name: 'iPhone 15 Pro Max',
        category: 'iOS',
        width: 430,
        height: 932,
        devicePixelRatio: 3,
    },
    {
        name: 'iPhone 15',
        category: 'iOS',
        width: 393,
        height: 852,
        devicePixelRatio: 3,
    },
    {
        name: 'iPhone SE (3rd gen)',
        category: 'iOS',
        width: 375,
        height: 667,
        devicePixelRatio: 2,
    },
    {
        name: 'iPhone 14',
        category: 'iOS',
        width: 390,
        height: 844,
        devicePixelRatio: 3,
    },
    {
        name: 'iPad Pro 12.9"',
        category: 'iOS',
        width: 1024,
        height: 1366,
        devicePixelRatio: 2,
    },
    {
        name: 'iPad Pro 11"',
        category: 'iOS',
        width: 834,
        height: 1194,
        devicePixelRatio: 2,
    },
    {
        name: 'iPad Air',
        category: 'iOS',
        width: 820,
        height: 1180,
        devicePixelRatio: 2,
    },
    {
        name: 'iPad Mini',
        category: 'iOS',
        width: 744,
        height: 1133,
        devicePixelRatio: 2,
    },

    // Android Devices
    {
        name: 'Samsung Galaxy S24 Ultra',
        category: 'Android',
        width: 412,
        height: 915,
        devicePixelRatio: 3.5,
    },
    {
        name: 'Samsung Galaxy S24',
        category: 'Android',
        width: 360,
        height: 780,
        devicePixelRatio: 3,
    },
    {
        name: 'Samsung Galaxy S23',
        category: 'Android',
        width: 360,
        height: 780,
        devicePixelRatio: 3,
    },
    {
        name: 'Google Pixel 8 Pro',
        category: 'Android',
        width: 448,
        height: 998,
        devicePixelRatio: 2.625,
    },
    {
        name: 'Google Pixel 8',
        category: 'Android',
        width: 412,
        height: 915,
        devicePixelRatio: 2.625,
    },
    {
        name: 'Google Pixel 7',
        category: 'Android',
        width: 412,
        height: 915,
        devicePixelRatio: 2.625,
    },
    {
        name: 'Samsung Galaxy Fold 5 (folded)',
        category: 'Android',
        width: 374,
        height: 841,
        devicePixelRatio: 3,
    },
    {
        name: 'Samsung Galaxy Fold 5 (unfolded)',
        category: 'Android',
        width: 673,
        height: 841,
        devicePixelRatio: 3,
    },
    {
        name: 'Samsung Galaxy Tab S9',
        category: 'Android',
        width: 753,
        height: 1193,
        devicePixelRatio: 2,
    },

    // Desktop
    {
        name: 'Desktop 1920×1080 (FHD)',
        category: 'Desktop',
        width: 1920,
        height: 1080,
        devicePixelRatio: 1,
    },
    {
        name: 'Desktop 2560×1440 (QHD)',
        category: 'Desktop',
        width: 2560,
        height: 1440,
        devicePixelRatio: 1,
    },
    {
        name: 'Desktop 1440×900',
        category: 'Desktop',
        width: 1440,
        height: 900,
        devicePixelRatio: 1,
    },
    {
        name: 'Desktop 1366×768',
        category: 'Desktop',
        width: 1366,
        height: 768,
        devicePixelRatio: 1,
    },
    {
        name: 'MacBook Pro 14"',
        category: 'Desktop',
        width: 1512,
        height: 982,
        devicePixelRatio: 2,
    },
    {
        name: 'MacBook Pro 16"',
        category: 'Desktop',
        width: 1728,
        height: 1117,
        devicePixelRatio: 2,
    },
    {
        name: 'MacBook Air 13"',
        category: 'Desktop',
        width: 1470,
        height: 956,
        devicePixelRatio: 2,
    },
];

/**
 * Format a resolution for display in the quick pick.
 * Example: "iPhone 15 Pro (1179×2556)" showing physical pixels
 */
export function formatResolutionLabel(res: DeviceResolution): string {
    const physicalWidth = Math.round(res.width * res.devicePixelRatio);
    const physicalHeight = Math.round(res.height * res.devicePixelRatio);
    return `${res.name} (${physicalWidth}×${physicalHeight})`;
}

/**
 * Format resolution detail for the quick pick description.
 * Example: "393×852 @3x logical"
 */
export function formatResolutionDetail(res: DeviceResolution): string {
    return `${res.width}×${res.height} @${res.devicePixelRatio}x logical`;
}

/**
 * Get resolution by name.
 */
export function getResolutionByName(name: string): DeviceResolution | undefined {
    return DEVICE_RESOLUTIONS.find(r => r.name === name);
}

/**
 * Get the default resolution (iPhone 15 Pro).
 */
export function getDefaultResolution(): DeviceResolution {
    return DEVICE_RESOLUTIONS.find(r => r.name === 'iPhone 15 Pro') ?? DEVICE_RESOLUTIONS[0];
}

/**
 * Group resolutions by category for grouped quick pick display.
 */
export function getResolutionsByCategory(): Map<string, DeviceResolution[]> {
    const grouped = new Map<string, DeviceResolution[]>();
    for (const res of DEVICE_RESOLUTIONS) {
        const existing = grouped.get(res.category) ?? [];
        existing.push(res);
        grouped.set(res.category, existing);
    }
    return grouped;
}
