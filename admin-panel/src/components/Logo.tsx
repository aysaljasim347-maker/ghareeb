import React from 'react';

interface LogoProps {
  size?: number;
  color?: string;
  showText?: boolean;
}

const Logo: React.FC<LogoProps> = ({ size = 32, color = '#1B6B4A', showText = false }) => {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
      <svg 
        width={size} 
        height={size} 
        viewBox="0 0 100 100" 
        fill="none" 
        xmlns="http://www.w3.org/2000/svg"
      >
        <circle 
          cx="50" 
          cy="50" 
          r="46" 
          stroke={color} 
          strokeWidth="4" 
          strokeDasharray="8 4"
        />
        <path 
          d="M50 75C50 75 22 56 22 37C22 24 38 21 50 34C62 21 78 24 78 37C78 56 50 75 50 75Z" 
          fill={color}
        />
        <path 
          d="M30 50H70" 
          stroke="white" 
          strokeWidth="3" 
          strokeLinecap="round" 
          opacity="0.8"
        />
        <path 
          d="M50 35V65" 
          stroke="white" 
          strokeWidth="3" 
          strokeLinecap="round" 
          opacity="0.8"
        />
      </svg>
      {showText && (
        <span style={{ 
          fontSize: `${size * 0.6}px`, 
          fontWeight: 800, 
          color: color, 
          letterSpacing: '-0.5px' 
        }}>
          ReliefNet
        </span>
      )}
    </div>
  );
};

export default Logo;
