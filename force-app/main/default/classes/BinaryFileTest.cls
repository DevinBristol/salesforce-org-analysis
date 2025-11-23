/**
 * Created by Devin on 5/15/2024.
 */
@IsTest
public with sharing class BinaryFileTest {

    @IsTest
    public static void runBinaryFileTest(){
        Blob testBlob = Blob.valueOf('123');
        String fileName = 'testFile';
        String boundary = 'testBoundary';
        BinaryFile testBinaryFile = new BinaryFile(testBlob,fileName,boundary);


        Assert.areNotEqual(testBlob.size(),testBinaryFile.fileAsBlob.size());
    }

    @IsTest
    public static void runBinaryFileTestEncoded(){
        Blob testBlob = Blob.valueOf('123');
        String fileName = 'testFile';
        String boundary = 'testBoundary';
        BinaryFile testBinaryFile = new BinaryFile(testBlob,fileName,boundary,true);

        Assert.isNotNull(testBinaryFile.fileAsString);
    }

    }