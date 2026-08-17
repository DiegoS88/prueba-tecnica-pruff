# Seed demo: crea un usuario demo. Los datos (facturas/movimientos) se cargan
# desde la UI en Importar → Nueva importación.
# Uso: bin/rails db:seed
user = User.find_or_create_by!(email_address: "demo@pruff.cl") do |u|
  u.password = "password123"
end
puts "Usuario demo: #{user.email_address} / password123"
puts "Los datos se cargan desde la pestaña Importar."
