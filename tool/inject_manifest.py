from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text()
inject = """    <uses-permission android:name="android.permission.CAMERA"/>
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="upi" android:host="pay"/>
        </intent>
        <package android:name="com.google.android.apps.nbu.paisa.user"/>
        <package android:name="com.phonepe.app"/>
        <package android:name="net.one97.paytm"/>
        <package android:name="in.org.npci.upiapp"/>
        <package android:name="com.dreamplug.androidapp"/>
        <package android:name="in.amazon.mShop.android.shopping"/>
        <package android:name="com.whatsapp"/>
    </queries>
    """
text = text.replace("<application", inject + "<application", 1)
text = text.replace('android:label="upi_router"', 'android:label="PayLane"')
p.write_text(text)
