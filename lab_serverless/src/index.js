const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { PutCommand, DynamoDBDocumentClient } = require("@aws-sdk/lib-dynamodb");
const { RekognitionClient, DetectLabelsCommand } = require("@aws-sdk/client-rekognition"); // ¡NUEVO! IA

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const rekClient = new RekognitionClient({}); // Iniciamos el cliente de Rekognition

exports.handler = async (event) => {
    console.log("¡He despertado! Procesando imagen con IA...");

    for (const record of event.Records) {
        const bucketName = record.s3.bucket.name;
        const objectKey = record.s3.object.key;
        const eventTime = record.eventTime;

        try {
            // 1. Le pedimos a Rekognition que analice la foto
            const rekParams = {
                Image: { S3Object: { Bucket: bucketName, Name: objectKey } },
                MaxLabels: 3,       // Queremos el Top 3 de etiquetas
                MinConfidence: 75   // Solo si está más de un 75% seguro
            };
            
            const iaResponse = await rekClient.send(new DetectLabelsCommand(rekParams));
            
            // Extraemos solo los nombres de las etiquetas (Ej: ["Dog", "Puppy", "Pet"])
            const etiquetas = iaResponse.Labels.map(l => l.Name);
            console.log(`Etiquetas de la IA para ${objectKey}:`, etiquetas);

            // 2. Guardamos en la base de datos (ahora incluyendo el array de etiquetas)
            const dbParams = {
                TableName: process.env.DYNAMODB_TABLE_NAME,
                Item: {
                    imageId: objectKey,
                    bucket: bucketName,
                    uploadTime: eventTime,
                    status: "ANALIZADO_POR_IA",
                    labels: etiquetas // <--- ¡LA MAGIA DE LA IA SE GUARDA AQUÍ!
                }
            };

            await docClient.send(new PutCommand(dbParams));
            console.log(`✅ IA aplicada y datos guardados para ${objectKey}`);

        } catch (err) {
            console.error("❌ Error procesando la imagen con IA:", err);
        }
    }
    
    return { statusCode: 200, body: 'Procesamiento IA completado' };
};