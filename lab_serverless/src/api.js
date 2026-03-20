const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { ScanCommand, DynamoDBDocumentClient } = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
    console.log("¡Han llamado a la puerta! Petición HTTP recibida.");

    const params = {
        TableName: process.env.DYNAMODB_TABLE_NAME
    };

    try {
        // Escaneamos la base de datos para sacar todos los registros
        const data = await docClient.send(new ScanCommand(params));
        
        // Devolvemos la respuesta formateada como JSON para el navegador
        return {
            statusCode: 200,
            headers: { 
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*" // Permite que cualquier web lea esta API (CORS)
            },
            body: JSON.stringify(data.Items)
        };
    } catch (err) {
        console.error("Error leyendo de DynamoDB:", err);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: "Ocurrió un error en el servidor" })
        };
    }
};