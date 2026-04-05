const { Client } = require('pg');
const fs = require('fs');

async function run() {
    const client = new Client({
        connectionString: 'postgresql://postgres.kuegtgdxxfqfrtdhbfju:eddyfizio1208@aws-1-us-east-2.pooler.supabase.com:5432/postgres',
    });

    try {
        await client.connect();
        console.log('Connected to database...');
        
        let sql = fs.readFileSync('C:\\Users\\Anghelo\\.gemini\\antigravity\\scratch\\geofencing_system\\schema.sql', 'utf8');
        sql = sql.replace(/^\uFEFF/, "");
        
        await client.query(sql);
        console.log('Schema applied successfully!');
    } catch (err) {
        console.error('Error applying schema: ', err.message);
    } finally {
        await client.end();
    }
}

run();
