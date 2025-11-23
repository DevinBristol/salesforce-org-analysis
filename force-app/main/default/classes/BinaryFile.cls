/**
 * Created by Devin on 5/9/2024.
 */

public class BinaryFile {

    private static final Boolean DEFAULT_ENCODED = false;

    public BinaryFile(Blob resBodyBlob,String fileName, String boundary, Boolean Encoded){

        String header = '--'+boundary+'\nContent-Disposition: form-data; name="audioFileData"; filename="'+fileName+'";\nContent-Type: application/octet-stream';
        String footer = '--'+boundary+'--';
        String headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header+'\r\n\r\n'));
        while(headerEncoded.endsWith('=')){
            header +=' ';
            headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header+'\r\n\r\n'));
        }
        String bodyEncoded = EncodingUtil.base64Encode(resBodyBlob);
        Blob bodyBlob = null;
        String last4Bytes = bodyEncoded.substring(bodyEncoded.length()-4,bodyEncoded.length());
        if(last4Bytes.endsWith('==')) {
            last4Bytes = last4Bytes.substring(0,2) + '0K';
            bodyEncoded = bodyEncoded.substring(0,bodyEncoded.length()-4) + last4Bytes;
            String footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
            bodyBlob = EncodingUtil.base64Decode(headerEncoded+bodyEncoded+footerEncoded);
        } else if(last4Bytes.endsWith('=')) {
            last4Bytes = last4Bytes.substring(0,3) + 'N';
            bodyEncoded = bodyEncoded.substring(0,bodyEncoded.length()-4) + last4Bytes;
            footer = '\n' + footer; String footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
            bodyBlob = EncodingUtil.base64Decode(headerEncoded+bodyEncoded+footerEncoded);
        } else {
            footer = '\r\n' + footer;
            String footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
            bodyBlob = EncodingUtil.base64Decode(headerEncoded+bodyEncoded+footerEncoded);
        }
        if(Encoded==true){
            this.fileAsString = bodyBlob.toString();
        } else {
            this.fileAsBlob = bodyBlob;
        }
    }
    public BinaryFile(Blob resBodyBlob,String fileName, String boundary){
        this(resBodyBlob,fileName,boundary,DEFAULT_ENCODED);
    }

    public String fileAsString { get; private set; }
    public Blob fileAsBlob { get; private set; }
}