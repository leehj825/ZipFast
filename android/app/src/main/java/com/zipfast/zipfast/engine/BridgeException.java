package com.zipfast.zipfast.engine;

/** Failure with a stable [code] that the Dart side maps to a typed exception. */
public final class BridgeException extends Exception {
    public static final String PASSWORD_REQUIRED = "PASSWORD_REQUIRED";
    public static final String WRONG_PASSWORD = "WRONG_PASSWORD";
    public static final String UNSUPPORTED = "UNSUPPORTED";
    public static final String CORRUPT = "CORRUPT";
    public static final String CANCELLED = "CANCELLED";

    public final String code;

    public BridgeException(String code, String message) {
        super(message);
        this.code = code;
    }
}
