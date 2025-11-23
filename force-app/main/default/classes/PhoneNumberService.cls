/**
 * Created by Devin on 6/4/2024.
 */

public with sharing class PhoneNumberService {

    public static String DeformatPhone(String Phone) {

        String nonDigits = '[^0-9]';
        String PhoneDigits;
        // remove all non numeric
        PhoneDigits = Phone.replaceAll(nonDigits,'');
        PhoneDigits = PhoneDigits.removeStart('1');
        return PhoneDigits;
    }

}